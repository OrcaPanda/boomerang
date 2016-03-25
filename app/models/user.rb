require 'bcrypt'

class User 
  include Neo4j::ActiveNode
  include Neo4j::Timestamps
  include BCrypt
  property :name, type: String
  property :surname, type: String
  property :email, type: String
  property :password_digest, type: String
  property :remember_digest, type: String
  property :admin, type: String
  property :activation_digest, type: String
  property :activated, type: String
  property :activated_at, type: DateTime

  has_many :both, :users, rel_class: :FriendsWith

	attr_accessor :password

	before_save :downcase_email, :encrypt_password

	validates :name, presence: true, length: {maximum: 50}
	validates :surname, presence: true, length: {maximum: 50}

	VALID_EMAIL_REGEX = /\A([\w+\-].?)+@[a-z\d\-]+(\.[a-z]+)*\.[a-z]+\z/i
	validates :email, presence: true, length: {maximum: 255}, format: {with: VALID_EMAIL_REGEX}, uniqueness: {case_sensitive: false}

	validates :password, presence: true, length: {in: 6..255}, confirmation: true

#	def password
#		@password ||= Password.new(password_digest)
#	end
	
#	def password=(new_password)
#		@password = Password.create(new_password)
#		self.password_digest = @password
#	end

	def make_friend(other_user)
		friendship = FriendsWith.create(from_node: self, to_node: other_user, created_at: DateTime.now)
	end
				

	private
		def downcase_email
			self.email = email.downcase
		end

		def encrypt_password
			@password = Password.create(password)
			self.password_digest = @password
		end
end
