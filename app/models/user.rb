require 'bcrypt'
require 'net/http'

class User 
  include Neo4j::ActiveNode
  include Neo4j::Timestamps
  include BCrypt
  property :name, type: String
  property :surname, type: String
  property :email, type: String, index: :exact
  property :password_digest, type: String
  property :remember_digest, type: String
  property :admin, type: String
  property :budget, type: BigDecimal, default: 100
  property :activation_digest, type: String
  property :activated, type: String
  property :activated_at, type: DateTime

#  property :pending_friend_requests, default: Hash.new	#Makes pending_friend_requests a hash
#  serialize :pending_friend_requests
  
  
  has_many :both, :users, model_class: :User, rel_class: :Friend, unique: true
  has_many :in, :users, model_class: :User, rel_class: :PendingFriendRequest, unique: true
  has_many :out, :users, model_class: :User, rel_class: :PendingFriendRequest, unique: true

  has_many :both, :users, model_class: :User, rel_class: :Debt, unique: true

	attr_accessor :password

	before_save :downcase_email, :encrypt_password

	validates :name, presence: true, length: {maximum: 50}
	validates :surname, presence: true, length: {maximum: 50}

	VALID_EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
	validates :email, presence: true, length: {maximum: 255}, format: {with: VALID_EMAIL_REGEX}, uniqueness: {case_sensitive: false}

	validates :password, presence: true, length: {in: 6..255}, confirmation: true, allow_nil: true

#	def password
#		@password ||= Password.new(password_digest)
#	end
	
#	def password=(new_password)
#		@password = Password.create(new_password)
#		self.password_digest = @password
#	end

				
#	def request_friend_with(other_user)
#		if(accept_friend_request(other_user)) # Sees if there are pending friendships to me, so if I make a new request it should complete the friendship
#	
#		else
#			self_key = self.email.to_sym
#			other_user.pending_friend_requests[self_key] = self if !other_user.pending_friend_requests.key?(self_key)
#		end
#	end
#	def accept_friend_request(other_user)
#		return nil if !self.pending_friend_requests.value?(other_user) 					#return nil if other_user is not in my pending requests list
#		friendship = FriendsWith.create(from_node: self, to_node: other_user, created_at: DateTime.now) #make the friendship relationship
#		self.pending_friend_requests.delete(other_user.email.to_sym) 					#remove the pending friendship request
#		return true
#	end
	

# FRIENDSHIP FORMING AND MANAGING
# NEED TO ADD TRANSACTION WRAPPING	
	def request_friend_with(other_user)
		return false if(self == other_user || friends_with(other_user))
		created_new_friendship = false
		pending_friend_requests.each do |relationship|
			if relationship.from_node == other_user
				make_friend(other_user)
				relationship.destroy
				created_new_friendship = true
				return true
			end
		end
		PendingFriendRequest.create(from_node:self, to_node: other_user) unless created_new_friendship
		return true
	end


	def accept_friend_request(other_user)
		if pending_friend_requests_contains(other_user)
			request_friend_with(other_user)
			return true
		end
		return false
	end

	def friends_with(other_user)
		return false if other_user == self
		rels.each do |relationship|
			if(relationship.rel_type.to_s == 'FRIEND' && (relationship.start_node == other_user || relationship.end_node == other_user))
				return true
			end
		end
		return false		
	end

	def pending_friend_requests
		pending_requests = Array.new
		self.rels.each do |relationship|
			if(relationship.rel_type.to_s == 'PENDING_FRIEND_REQUEST' && relationship.end_node == self)
				pending_requests << relationship
			end
		end
		return pending_requests
	end 

	def pending_friend_requests_contains(other_user)
		rels.each do |relationship|
			if(relationship.rel_type.to_s == 'PENDING_FRIEND_REQUEST' && relationship.end_node == self && relationship.from_node == other_user)
				return true
			end
		end
		return false
	end

	def destroy_friendship(other_user)
		rels.each do |relationship|
			if(relationship.rel_type.to_s == 'FRIEND' && (relationship.start_node == other_user || relationship.end_node == other_user))
				relationship.destroy
				return true
			end
		end
		return false
	end

# DEBT CREATION AND MANAGING

	#def add_debt(other_user, debt_amount = 0)
	#	return nil unless friends_with(other_user) && debt_amount > 0
	#	debt_amount = debt_amount.to_d
	#	#if bfs returns nil, then add a new debt path
	#	path = User.debt_bfs(self, other_user)
	#	if(path == nil)
	#		Debt.create(from_node:self, to_node: other_user, amount: debt_amount)
	#	else
	#		index = 0
	#		debt_path = Array.new
	#		path["relationships"].each do |edge|
	#			debt_path << edge.match(/(?<=http:\/\/localhost:7474\/db\/data\/relationship\/).+/).to_s
	#		end
	#		#If none of the locks are set, then set them all, or return nil
	#		DBSession.query("START n= node(#{debt_path.join(", ")}) n.lock_by = #{self.uuid.to_s}")

	#			puts "Paused"
	#			blah = gets
	#			#Need to check if Debt.find_by_id finds anytime for concurrency issue. Debt might be destroyed from other transactions. 
	#	#		begin
	#	#			debt_edge = Debt.find_by_id(edge.match(/(?<=http:\/\/localhost:7474\/db\/data\/relationship\/).+/).to_s)
	#	#			if(debt_edge.from_node.neo_id.to_s == path["nodes"][index].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s)
	#	#				debt_edge.add_delta(debt_amount)
	#	#			else 
	#	#				debt_edge.add_delta(debt_amount*(-1))
	#	#			end
	#	#			index += 1
	#	#		rescue NoMethodError
	#	#			#If there is an exception, then try to find a new debt path recursively
	#	#			add_debt(other_user, debt_amount)
	#	#		end
	#	#	end
	#	end
	#	return debt_amount
	#end

	def add_debt(other_user, debt_amount = 0)
		return nil unless debt_amount > 0 && friends_with(other_user)
		debt_amount = debt_amount.to_d
		path = User.debt_bfs(self, other_user)
			if(path == nil)
				Debt.create(from_node:self, to_node: other_user, amount: debt_amount)
			else
				index = 0
				debt_path = Array.new
				path["relationships"].each do |edge|
					debt_path << edge.match(/(?<=http:\/\/localhost:7474\/db\/data\/relationship\/).+/).to_s
				end
				#grab mutex on the affected relationships and/or nodes
				debughere('grab mutex')						
				begin
					tx = Neo4j::Transaction.new
					debughere('opened transaction')
					debt_path.each do |edge|
						debughere('one edge')
						debt_edge = Debt.find_by_id(edge)
						if(debt_edge.from_node.neo_id.to_s == path["nodes"][index].match(/(?<=http:\/\/localhost:7474\/db\/data\/node\/).+/).to_s)
							debt_edge.add_delta(debt_amount)
						else 
							debt_edge.add_delta(debt_amount*(-1))
						end
						index += 1
					end
					debughere('finished adding debt')
				rescue Exception
					puts 'no method error in add debt'
					tx.failure
					#add_debt(other_user, debt_amount)
				ensure
					tx.close
				end		
				#release mutex
			end
	end

	def self.debt_bfs(user_A, user_B, depth = 8)
		base_url = 'http://localhost:7474/db/data/node/' 
		start_node_id = user_A.neo_id		

		command_format = base_url + start_node_id.to_s + '/path'

		url = URI.parse(command_format)
		req = Net::HTTP::Post.new(url.to_s, initheader = {'Content-Type' => 'application/json'})

		payload = {
			"order" => "breadth_first",
			"relationships" => {
				"type" => "DEBT",
				"direction" => "all"
			},
			"uniqueness" => "node_global",
			"max_depth" => depth,
			#"return_filter" => {
			#	"body" => "position.endNode().getProperty('email').eql?(#{user_B.email})"
			#}
			"to" => base_url + user_B.neo_id.to_s,
			"algorithm" => "shortestPath"
		}
		
		req.body = payload.to_json
		res = Net::HTTP.start(url.host, url.port) do |http|
			http.request(req)
		end
		results = JSON.parse(res.body)
		return nil if results.key?("errors")
		results 
	end

	def self.db_get()
		url = URI.parse('http://localhost:7474/db/data/relationship/types')
		req = Net::HTTP::Get.new(url.to_s)
		res = Net::HTTP.start(url.host, url.port) do |http|
			http.request(req)
		end
		puts res.body
	end
# a = User.all[0];b = User.all[1];c = User.all[2];d = User.all[3];e = User.all[4]

	def debughere(message)
		puts message unless message == nil
		a = gets
	end

	class DebtNonExistentError < NoMethodError
	#Exception for in case a debt is deleted before the debt tree can be evaluated
	end
# PRIVATE METHODS

	private
		def downcase_email
			self.email = email.downcase
		end

		def encrypt_password
			@password = Password.create(password)
			self.password_digest = @password
		end

		def make_friend(other_user)
			Friend.create(from_node: other_user, to_node: self)
		end
end
