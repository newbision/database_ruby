class ProductSpec < ActiveRecord::Base

belongs_to :product
belongs_to :spec_type

	def self.fetch(key)
		joins(:spec_type).where(:spec_types=>{:name=>key})
	end

end
