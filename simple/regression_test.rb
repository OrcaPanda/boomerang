#!/usr/local/bin/ruby
#This validation will be performed solely at the database level because this is a backend database correctness test

require_relative 'simplifier.rb'
require 'benchmark'

class TestFixture

	@@number_of_simplifies = 0

	def initialize
		Dir.chdir(Dir.pwd.to_s)
		puts 'Running: rake neo4j:reset_yes_i_am_sure'
		`rake neo4j:reset_yes_i_am_sure`
		puts 'Database resetted'
	end

	def setup_users(number_people)
		#first reset the database
		for index in 0...number_people
			new_user(index.to_s)
		end
		@people = Array.new(number_people, BigDecimal.new(0.to_s))
		@actual_debts = Array.new(number_people, BigDecimal.new(0.to_s))
		@completed = false
	end

	def setup_pending_debts(debt_density, max_amount)
		#Number of debts = (NUMBER OF PEOPLE)^2 X %(DEBT DENSITY)
		number_of_people = @people.size
		for person in 0...number_of_people
			(debt_density * number_of_people / 100).to_i.times do 
				target = Random.rand(number_of_people)
				while(target == person) do
					target = Random.rand(number_of_people)
				end
				amount = BigDecimal.new(Random.rand(max_amount.to_f).round(2).to_s)
				@people[person] += amount
				@people[target] -= amount
				add_pending(person, target, amount)
			end
		end
	end

	def puts_net_expected_debt()
		for person in 0...@people.size
			puts "Person #{person.to_s}'s net expected debt is #{@people[person].to_s}"	
		end
	end

	def compute_until_simplified()
		simple = Simpler.new()
		v = Benchmark.bmbm do |x|
			x.report("total") {
				while(simple.simplify() != nil)
					@@number_of_simplifies += 1
				end
			}
		end
		@completed = true
	end

	def puts_net_actual_debt()
		puts "Simplification incomplete" unless @completed
		for person in 0...@people.size
			net_debt = get_net_debt(person)
			@actual_debts[person] = net_debt
			puts "Person #{person.to_s}'s net actual debt is #{net_debt}"
		end
	end			

	def verify_correctness()
		correct = true
		for person in 0...@people.size
			if BigDecimal(@people[person].to_s) != BigDecimal(@actual_debts[person].to_s)
				correct = false
			end
		end
		puts ""
		if correct
			puts "*************************************"
			puts "*                                   *"
			puts "*             CORRECT               *"
			puts "*                                   *"
			puts "*************************************"
		else
			puts "*************************************"
			puts "*                                   *"
			puts "*            INCORRECT              *"
			puts "*                                   *"
			puts "*************************************"
		end
		puts ""
		puts "number of simplifies used: #{@@number_of_simplifies.to_s}"
	end

	def get_net_debt(id)
		relative_url = 'db/data/node/' + id.to_s + '/relationships/all/DEBT'
		result = JSON.parse(serve('GET', relative_url))
		net_debt = BigDecimal.new(0)
		#puts result
		result.each do |rel|
			if rel["start"].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s == id.to_s
				net_debt += BigDecimal.new(rel["data"]["amount"].to_s)
			else 
				net_debt -= BigDecimal.new(rel["data"]["amount"].to_s)
			end
		end
		return net_debt.to_s
	end

	def get_net_worth(id)
		return (BigDecimal.new(get_net_debt(id)) * BigDecimal.new(-1)).to_s
	end

	def add_pending(a_id, b_id, amount)
		relative_url = 'db/data/node/' + a_id.to_s + '/relationships'
		payload = {
			"to" => 'http://localhost:7474/db/data/node/' + b_id.to_s,
			"type" => "PENDING_DEBT",
			"data" => {
				"amount" => BigDecimal.new(amount.to_s).to_s
			}
		}
		result = serve('POST', relative_url, payload)
		puts "Created PendingDebt from User_#{a_id.to_s} to User_#{b_id.to_s} of amount: #{amount.to_s}"
	end
#	def new_user(identity)
#		relative_url = 'users'
#		payload = {
#			"user" => {
#				"name" => "Person #{identity}",
#				"surname" => "Surname #{identity}",
#				"email" => "person_#{identity}@email.com",
#				"password" => "abc123",
#				"password_confirmation" => "abc123"
#				}
#		}
#		serve('POST', relative_url, payload)
#	end

	def new_user(identity)
		identity = identity.to_s
		relative_url = 'db/data/node'
		payload = {
			"name" => "Person #{identity}",
			"surname" => "Surname #{identity}",
			"email" => "person_#{identity}@email.com",
			"password" => "abc123",
			"password_confirmation" => "abc123"
		}
		result = serve('POST', relative_url, payload)
		id = JSON.parse(result)["metadata"]["id"].to_s
		relative_url = 'db/data/node/' + id + '/labels'
		payload = "User"
		serve('POST', relative_url, payload)
		puts "Created User \"Person #{identity}\""
	end

	def serve(verb, relative_url, payload = nil)
		base_url = 'http://localhost:7474/'
		combined_url = base_url + relative_url
		url = URI.parse(combined_url)
		case verb
		when 'POST'
			req = Net::HTTP::Post.new(url.to_s)
			req["content-type"] = 'application/json'
			req.body = payload.to_json
		when 'GET'
			req = Net::HTTP::Get.new(url.to_s)
		end
		res = Net::HTTP.start(url.host, url.port) do |http|
			http.request(req)
		end
		res.body
	end
end

def debug(message)
	puts message
	a = gets
end

t = TestFixture.new()
t.setup_users(10)
t.setup_pending_debts(50, 100)
t.puts_net_expected_debt()
debug("Waiting for input")
t.compute_until_simplified()
t.puts_net_actual_debt()
t.verify_correctness()
