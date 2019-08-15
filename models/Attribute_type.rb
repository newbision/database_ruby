class AttributeType < ActiveRecord::Base

	has_many :product_attributes, :dependent => :destroy
	has_many :products, through: :attributes

end