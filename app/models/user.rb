require 'bcrypt'
require 'net/http'
require 'json'

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
  property :activation_digest, type: String
  property :activated, type: String
  property :activated_at, type: DateTime

#  property :pending_friend_requests, default: Hash.new	#Makes pending_friend_requests a hash
#  serialize :pending_friend_requests
  
  
  has_many :both, :users, model_class: :User, rel_class: :Friend, unique: true
  has_many :in, :users, model_class: :User, rel_class: :PendingFriendRequest, unique: true
  has_many :out, :users, model_class: :User, rel_class: :PendingFriendRequest, unique: true


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
	
	def request_friend_with(other_user)
		return false if(friends_with(other_user) || self == other_user)
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

	def add_debt(other_user, debt_amount = 0)
		return nil unless friends_with(other_user) && debt_amount != 0
			
	end

	def self.debt_bfs(user_A, user_B, depth = 8)
		base_url = 'http://localhost:7474/db/data/node/' 
		start_node_id = user_A.neo_id		

		command_format = base_url + start_node_id.to_s + '/traverse/path'

		url = URI.parse(command_format)
		req = Net::HTTP::Post.new(url.to_s)
		data_hash = Hash.new
		
		data_hash["order"] = "breadth_first"
		data_hash["relationships"] = "all"
		data_hash["uniqueness"] = "node_global"
		data_hash["return_filter"] = 
		

		req.set_form_data(data_hash)
		res = Net::HTTP.start(url.host, url.port) do |http|
			http.request(req)
		end
		puts res.body
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
