class SpecType < ActiveRecord::Base

	has_many :product_specs, :dependent => :destroy
	has_many :products, through: :product_specs

	def spec
		product_specs.map(&:product)
	end

end