#!/usr/local/bin/ruby
require 'net/http'
require 'json'
require 'bigdecimal'

class Simpler
	def simplify()
		group = retrieve_pending()
		return if group.nil?
		pending_id = group[0]
		amount = group[1]
		from_id = group[2]
		to_id = group[3]
		path = debt_bfs(from_id, to_id)
		if path.nil? || path.empty?
			create_debt(from_id, to_id, amount)
		else
			index = 0
			path['edges'].each do |edge|
				update_debt(edge, path['nodes'][index], amount) #check for directionality. If inline, add, else subtract. Fix in update_amount
			index += 1
			end
		end
		destroy_rel(pending_id)
	end

	def retrieve_pending()
		#MATCH (n)-[r:FRIEND]->(c) RETURN r ORDER BY r.created_at ASC LIMIT 1
		relative_url = 'db/data/transaction/commit'
		payload = {
			"statements" => [{
				"statement" => "MATCH (f)-[r:PENDING_DEBT]->(t) RETURN id(r),r.amount,id(f),id(t) ORDER BY r.created_at ASC LIMIT 1"
			}]
		}
		result = server_request('POST', relative_url, payload)
		begin
			id = result["results"][0]["data"][0]["row"][0].to_s
			amount = result["results"][0]["data"][0]["row"][1].to_s
			f = result["results"][0]["data"][0]["row"][2].to_s
			t = result["results"][0]["data"][0]["row"][3].to_s
			if(BigDecimal(result["results"][0]["data"][0]["row"][1].to_s) < 0)
				from = t
				to = f
			else
				from = f
				to = t
			end
			group = Array.new
			group = [id, amount, from, to]
		rescue NoMethodError
			group = nil
		end
		return group
	end

	def destroy_rel(id)
		relative_url = 'db/data/relationship/' + id.to_s
		server_request('DELETE', relative_url)
	end

	def create_debt(user_a_id, user_b_id, amount)
		base_url = 'http://localhost:7474/'
		relative_url = 'db/data/node/' + user_a_id.to_s + '/relationships'
		payload = {
			"to" => base_url + 'db/data/node/' + user_b_id.to_s,
			"type" => "DEBT",
			"data" => {
				"amount" => BigDecimal(amount).to_s
			}
		}
		result = server_request('POST', relative_url, payload)
		result != nil
	end

	def update_debt(id,from_node, delta)
		#relative_url = 'db/data/relationship/' + id.to_s + '/properties/amount'
		relative_url = 'db/data/node/' + from_node.to_s + '/relationships/all'
		result = server_request('GET', relative_url)
		#puts "Result from server_request is: "
		return false if result == nil
		inline = false
		current_amount = 0
		result.each do |edge|
			if edge["metadata"]["id"].to_s == id.to_s
				current_amount = edge["data"]["amount"]
				if edge["start"].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s == from_node.to_s
					inline = true
				end
				break
			end
		end
		if inline
			new_amount = BigDecimal.new(current_amount) + BigDecimal(delta.to_s)
		else
			new_amount = BigDecimal.new(current_amount) - BigDecimal(delta.to_s)
		end
		if new_amount == BigDecimal(0)
			destroy_rel(id)
		else
			payload = new_amount.to_s
		#print "Payload is: "
		#puts payload
			relative_url = 'db/data/relationship/' + id.to_s + '/properties/amount'
			server_request('PUT', relative_url, payload)
		end
		return true
	end

	def debt_bfs(user_a_id, user_b_id, depth = 8)
		base_url = 'http://localhost:7474/'
		relative_url = 'db/data/node/' + user_a_id.to_s + '/path'
		payload = {
			"order" => "breadth_first",
			"relationships" => {
				#"type" => "DEBT",
				"type" => "DEBT",
				"direction" => "all"
				},
			"uniqueness" => "node_global",
			"max_depth" => depth,
			"to" => base_url + 'db/data/node/' + user_b_id.to_s,
			"algorithm" => "shortestPath"
		}
		result = server_request('POST',relative_url, payload)
		#p result
		return nil if result.nil?
		debt_path = Array.new
		debt_node = Array.new
		result["relationships"].each do |edge|
			debt_path << edge.match(/(?<=http:\/\/localhost:7474\/db\/data\/relationship\/).+/).to_s
		end
		result["nodes"].each do |node|
			debt_node << node.match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s
		end
		path = {'nodes' => debt_node, 'edges' => debt_path}
		return path
	end

	def server_request(verb, relative_url, json_payload = nil)
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
	end
end #End Class

