class Property < ActiveRecord::Base

	has_many :product_properties, :dependent => :destroy
	has_many :products, :through => :product_properties

end