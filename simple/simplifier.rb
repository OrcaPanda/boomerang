#!/usr/local/bin/ruby
require 'net/http'
require 'json'
require 'bigdecimal'

def simplify()
	group = retrieve_pending()
	return if group.nil?
	pending_id = group[0]
	amount = group[1]
	from_id = group[2]
	to_id = group[3]
	path = debt_bfs(from_id, to_id)
	if path.empty?
		create_debt(from_id, to_id, amount)
	else
		path.each do |edge|
			update_debt(edge, amount) #check for directionality. If inline, add, else subtract. Fix in update_amount
		end
	end
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
	#Check if a relationship already exists
	#relative_url = 'db/data/node/' + user_a_id.to_s + '/relationships/all/DEBT'
	#result = server_request('GET', relative_url)
	#puts result
	#exit

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

def update_debt(id, delta)
	relative_url = 'db/data/relationship/' + id.to_s + '/properties/amount'
	result = server_request('GET', relative_url)
	#print "Result from server_request is: "
	#puts result
	return false if result == nil
	result = result.match(/(?!")(.*)(?=")/).to_s
	#print "Post match result is: "
	#puts result
	new_amount = BigDecimal.new(result) + BigDecimal(delta.to_s)
	payload = new_amount.to_s
	#print "Payload is: "
	#puts payload
	server_request('PUT', relative_url, payload)
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
	debt_path = Array.new
	result["relationships"].each do |edge|
		debt_path << edge.match(/(?<=http:\/\/localhost:7474\/db\/data\/relationship\/).+/).to_s
	end
	return debt_path
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
		result = nil if result.key?("errors") && !result["errors"].empty?
	rescue JSON::ParserError
		result = res.body
	end
	return result
end

puts retrieve_pending()
