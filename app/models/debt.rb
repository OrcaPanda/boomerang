class Debt 
  include Neo4j::ActiveRel
  include Neo4j::Timestamps

	creates_unique

	from_class :User
	to_class :User
	
	property :amount, type: String

	def add_delta(delta)
		new_amount = self.amount + delta.to_d
		if(new_amount < 0)
			updated_debt = Debt.new(created_at: self.created_at)
			from_node = self.from_node
			to_node = self.to_node
			self.destroy
			updated_debt.from_node = to_node
			updated_debt.to_node = from_node
			updated_debt.amount = new_amount.abs
			updated_debt.save
			
		elsif(new_amount == 0)
			self.destroy
		else
			self.amount = new_amount
			self.save
		end	
	end

	#def create
end
