class FriendsWith
	include Neo4j::ActiveRel
	
	from_class :User
	to_class :User
	type 'friends_with'

	property :created_at, type: DateTime
	


end
