class User 
  include Neo4j::ActiveNode
  property :name, type: String
  property :email, type: String
  property :password_digest, type: String
  property :remember_digest, type: String
  property :admin, type: String
  property :activation_digest, type: String
  property :activated, type: String
  property :activated_at, type: DateTime



end
