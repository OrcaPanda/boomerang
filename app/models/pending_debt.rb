class PendingDebt 
  include Neo4j::ActiveRel
  include Neo4j::Timestamps

	from_class :User
	to_class :User

	property :amount, type: String
end
