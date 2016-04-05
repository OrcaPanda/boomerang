module ApplicationHelper
	def full_title(page_title = '')
		base_title = "Boomerang"
		if page_title.empty?
			base_title
		else
			page_title + ' | ' + base_title
		end
	end

	class DBSession 
		@@session = Neo4j::Session.open(:server_db, "http://neo4j:pass@localhost:7474")
		
		def self.query(cypher_string)
			@@session.query(cypher_string)
		end
	end
end
