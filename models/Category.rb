class Category < ActiveRecord::Base
	acts_as_nested_set
	validates_uniqueness_of :name , scope: :parent_id
	has_many :product_categories, :dependent => :destroy
	has_many :products, :through => :product_categories
end