class ProductAttribute < ActiveRecord::Base

	belongs_to :product
	belongs_to :attribute_type

	def self.fetch(key)
		joins(:attribute_type).where(:attribute_types=>{:name=>key})
	end
end