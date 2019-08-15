class Integer
	def odd?
		self & 1 != 0
	end

	def even?
		self & 1 == 0
	end
end

class Identifier < ActiveRecord::Base
	has_many :products

	def self.format_type(id_type)
		id_type=id_type.downcase
		if ['upc', 'ucc-12', 'upc-a'].include? id_type
			id_type='gtin-14'
		elsif ['ean', 'jan', 'ean-13'].include? id_type
			id_type='gtin-14'
		elsif ['ean-8','upc-8'].include? id_type
			id_type='gtin-14'
		elsif ['ucc-14'].include? id_type
			id_type='gtin-14'
		else
			id_type
		end
	end

	def self.validate(id_type, id)
		if id_type=='gtin-14'
			id=Identifier.calc_gtin_checksum(id.to_i.to_s.rjust(14, "0"))
		elsif id_type=='isbn'
			id=Identifier.validate_isbn(id)
		elsif id.match(/^[0-9]*$/)
  			id=id.to_i.to_s
  		else
  			id.upcase
  		end
  		return id
	end

	def self.validate_isbn(isbn)
		if isbn.to_s.size<=10
			return calc_gtin_checksum('978'+isbn.to_i.to_s.rjust(10, "0"))
		else
			return calc_gtin_checksum(isbn.to_i.to_s.rjust(13, "0"))
		end
	end

	def self.calc_gtin_checksum(gtin)
		number = gtin.reverse
		odd = even = 0
		(1..number.length-1).each do |i|
			i.even? ? (even += number[i].chr.to_i) : (odd += number[i].chr.to_i*3)
		end
		number[0] = ((((odd+even)+(10-(odd+even)%10))-(odd + even))%10).to_s
		return number.reverse
	end
end