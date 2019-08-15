class Tag < ActiveRecord::Base

has_many :product_tags, :dependent => :destroy
has_many :products, through: :product_tags

self.inheritance_column = nil

end