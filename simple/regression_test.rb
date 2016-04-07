#!/usr/local/bin/ruby

require_relative 'simplifier.rb'

class TestFixture
	def setup(number_people, friendship_density)
		#first reset the database
		for index in 0...number_people
			new_user(index.to_s)
		end
		#Add friends
	end

	def new_user(identity)
		relative_url = 'users'
		payload = {
			"user" => {
				"name" => "Person #{identity}",
				"surname" => "Surname #{identity}",
				"email" => "person_#{identity}@email.com",
				"password" => "abc123",
				"password_confirmation" => "abc123"
				}
		}
		serve('POST', relative_url, payload)
	end

	def serve(verb, relative_url, payload = nil)
		base_url = 'http://localhost:3000/'
		combined_url = base_url + relative_url
		url = URI.parse(combined_url)
		case verb
		when 'POST'
			req = Net::HTTP::Post.new(url.to_s)
			req["content-type"] = 'application/json'
			req.body = payload.to_json
	
		end
		Net::HTTP.start(url.host, url.port) do |http|
			http.request(req)
		end
		#puts res.read_body
	end
end

t = TestFixture.new()
t.new_user()
