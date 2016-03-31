class Debt 
  include Neo4j::ActiveRel
  include Neo4j::Timestamps

	creates_unique

	from_class :User
	to_class :User
	
	property :amount, type: BigDecimal

	def add_delta(delta)
		new_amount = self.amount + delta.to_d
		if(new_amount < 0)
			temp_property = self.from_node
			self.from_node = self.to_node
			self.to_node = temp_property
			self.amount = new_amount.abs
			self.save
	
			updated_debt = Debt.create()
			self.destroy
			
		elsif(new_amount == 0)
			self.destroy
		else
			self.amount = new_amount
			self.save
		end	
	end

	def create
end
