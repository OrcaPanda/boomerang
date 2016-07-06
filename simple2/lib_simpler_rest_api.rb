#!/usr/local/bin/ruby
#This script contains classes and functions to facilitate editing the database based on the new algorithm's requirements

#To do list in this application:
#Function for computing net debt - DONE
#Setting and unsetting Simplified flag - DONE
#Retrieve a node without Simplified flag
#Check whether two nodes are friends - DONE
#Get a nodes incoming debts and/or outgoing debts
#Add a debt to make it vanish or update existing debt - returns status about what happened

require 'net/http'
require 'json'
require 'bigdecimal'

class Simpler2
	def check_friendship(user_a_id, user_b_id)
		relative_url = 'db/data/node/' + user_a_id.to_s + '/relationships/all/FRIEND'
		result = server_request('GET', relative_url, nil)
		result = JSON.parse(result)
		are_friends = false
		result.each do |rel|
			if((rel["start"].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s == user_b_id.to_s) || (rel["end"].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s == user_b_id.to_s))
				are_friends = true
				break
		end
		return are_friends
	end #End check_friendship method

	def get_net_debt(user_id)
		#This function computes the user's net debt worth by subtracting all incoming amounts from outgoing amounts
		net_debt_worth = BigDecimal.new(0)
		relative_url = 'db/data/node/' + user_id.to_s + '/relationships/all/DEBT'
		result = server_request('GET', relative_url, nil)
		result = JSON.parse(result)
		result.each do |rel|
			if(rel["start"].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/)    .+/).to_s == user_id.to_s) #If is is an outgoing edge
				net_debt_worth += BigDecimal.new(rel["data"]["amount"].to_s)
			else  #Otherwise it is an incoming edge
				net_debt_worth -= BigDecimal.new(rel["data"]["amount"].to_s)
			end
		end
		return net_debt_worth.to_s
	end #End get_net_debt method

 	def set_simplified_flag(user_id)
		#This method makes a request to the database to set the simplfied flag for a particular user
		relative_url = 'db/data/node/' + user_id.to_s + '/properties/simplified'
		payload = true
		result = server_request('PUT', relative_url, payload)
		#Database returns no data
	end
 
	def clear_simplified_flag(user_id)
		#This method makes a request to the database to clear the simplfied flag for a particular user
		relative_url = 'db/data/node/' + user_id.to_s + '/properties/simplified'
		payload = false
		result = server_request('PUT', relative_url, payload)
		#Database returns no data
	end

        def server_request(verb, relative_url, json_payload = nil)
		#This method makes generic requests to the Neo4j server
                base_url = 'http://localhost:7474/'
                combined_command = base_url + relative_url
                url = URI.parse(combined_command)
                case verb
                when 'POST'
                        req = Net::HTTP::Post.new(url.to_s, initheader = {'Content-Type' => 'application/json'})
                        req.body = json_payload.to_json
                when 'GET'
                        req = Net::HTTP::Get.new(url.to_s)
                when 'PUT'
                        req = Net::HTTP::Put.new(url.to_s, initheader = {'Content-Type' => 'application/json'})
                        req.body = json_payload.to_json
                when 'DELETE'
                        req = Net::HTTP::Delete.new(url.to_s)
                end

                res = Net::HTTP.start(url.host, url.port) do |http|
                        http.request(req)
                end
                return nil if res.body == nil 
                begin
                        result = JSON.parse(res.body)
                        result = nil if (result.is_a?(Hash) && result.key?("errors") && !result["errors"].empty?)
                rescue JSON::ParserError
                        result = res.body
                end
                return result
        end #End server_request method
end #End CLass

class Tester
	
end #End Class

app = Simpler2.new()
app.set_simplified_flag(0)
