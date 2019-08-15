class Product < ActiveRecord::Base

	has_many :product_tags, :dependent => :destroy
	has_many :tags, :through => :product_tags
	has_many :product_attributes, :dependent => :destroy
	has_many :attribute_types, :through => :product_attributes
	has_many :product_specs, :dependent => :destroy
	has_many :spec_types, :through => :product_specs
	has_many :product_categories, :dependent => :destroy
	has_many :categories, :through => :product_categories
	has_many :identifiers, :dependent => :destroy
	has_many :product_properties, :dependent => :destroy
	has_many :properties, :through => :product_properties
	has_many :awards, :dependent => :destroy

	scope :imported, -> { where("products.status != 'importing'") }
	scope :importing, -> { where(status:'importing') }

	default_scope {includes([:tags, :attribute_types, :spec_types, :categories, :identifiers, :properties])}

	def setValues(args)
		args.each do |k,v|
			instance_variable_set("@#{k}", v) unless v.nil?
		end
	end

	def self.find_by_indentifers(ids)
		cond=[]
		ids.each do |k,v|
			if cond[0].nil?
				cond[0]=""
			else
				cond[0]+=" OR "
			end
			cond[0]+="(identifiers.name=? AND identifiers.value=?)"
			cond<<k.to_s
			cond<<v.to_s
		end
		self.joins(:identifiers).where(cond)
	end

	def self.search(search_params)
		search_params[:page]||=1
		search_params[:per_page]||=10

		products = nil
		options = []
		conditions = ['']

		search_params.each do |key,value|
			if key == 'status'
				Array(value).each do |v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " products.status = ?" 
					conditions << v
				end
			end
			if key == 'attributes'
				options << :product_attributes
				options << :attribute_types
				value.each do |k,v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " attribute_types.name @@ to_tsquery(?) AND product_attributes.value = ? " 
					conditions << "%#{k}%"
					conditions << v
				end
			end
			if key == 'specs'
				options << :product_specs
				options << :spec_types
				value.each do |k,v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " spec_types.name @@ to_tsquery(?) AND product_specs.value = ? "
					conditions << "%#{k}%"
					conditions << v
				end
			end
			if key == 'tags'
				options << :product_tags
				options << :tags
				value.each do |k,v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " tags.name @@ to_tsquery(?) AND tags.value = ? "
					conditions << "%#{k}%"
					conditions << v
				end
			end

			if key == 'categories'
				options << :categories
				Array(value).each do |v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += "categories.name @@ to_tsquery(?)"
					conditions << "%#{v}%"
				end
			end

			if key == 'category_ids'
				options << :categories
				Array(value).each do |v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " categories.id = ? "
					conditions << "#{v}"
				end
			end

			if key == 'awards'
				options << :awards
				Array(value).each do |v|
					conditions[0] += " OR  " unless conditions.length == 1
					conditions[0] += " categories.key = ? "
					conditions << "%#{v}%"
				end
			end
			# if key == 'identifiers'
			# 	options << :identifiers
			# 	value.each do |k,v|
			# 		conditions[0] += " OR  " unless conditions.length == 1
			# 		conditions[0] += " identifiers.name = ? AND identifiers.value = ? "
			# 		conditions << k.downcase
			# 		conditions << v
			# 	end
			# end
		end

		if conditions.length > 1
			products = Product.select(:id).distinct.joins(options).where(conditions).page(search_params[:page]).per(search_params[:per_page])
		elsif search_params[:filter]=='orphans'
			products = Product.joins('LEFT JOIN identifiers ON "identifiers"."product_id" = "products"."id"').where('identifiers.id IS NULL').joins(options).where(conditions).group('products.id').page(search_params[:page]).per(search_params[:per_page])
		else
			products = Product.all.page(search_params[:page]).per(search_params[:per_page])
		end
		
		return products
	end

	def self.generate_product(product_data)
		product=Product.joins(:identifiers).where("identifiers.name='ASIN' && identifiers.value in (?)",Array(product_data[:identifiers][:ASIN])).group('products.id')
		product_data=product_data.transform_keys{|k| k.downcase.to_sym}
		if product.empty?
			product=Product.new(product_data.select{|k,v| Product.attribute_names.include? k.to_s.downcase if k!=:offers})
			product.short_description=product_data[:description] if product_data[:description]
			product.update_relelated_data(product_data.select{|k,v| [:attributes, :identifiers, :categories].include? k.downcase.to_sym})
			product.image_file=product_data[:offers][:Amazon][:image] if product_data[:offers][:Amazon][:image]
			product.save
			product.offers=product_data[:offers]
		end
		return product
	end

	def self.create_or_update(id_type, identifiers)
		products=[]
		identifiers.each do |identifier|
			product=import_product_by_id(id_type, identifier)
			if product
				products<<product
				identifiers.delete identifier
			end
		end
		return products, identifiers
	end

	def deep_hash(options={})
		data={}
		self.attributes.each do |attribute, value|
			data[attribute]=value if !value.nil?
		end

		data['categories']=categories_array if self.categories.size>0

		data['tags']=self.tags.collect{|a| a.name} if self.tags.size>0
		data['specs']=specs_hash if specs_hash.size>0
		data['attributes']=attributes_hash if attributes_hash.size>0
		data['identifiers']=identifiers_hash if identifiers_hash.size>0
		data['properties']=properties_hash if properties_hash.size>0
		data['awards']=awards_hash if awards_hash.size>0

		return data
	end



	def get_offers(options={})
		data={'name'=>self.name,'id'=>self.id, 'identifiers'=>self.identifiers_hash, 'status'=>self.status}

		begin
			Pumatra.settings.memcached.with do |conn|
				data['offers']=conn.get "#{self.id.to_s}/offers"
				expired=false
				data['offers'].each do |key, offer|
					expired=true if DateTime.parse(offer['expiration']) < DateTime.parse(Time.now.to_s)
				end
				data['offers']=nil if expired
			end if Pumatra.settings.memcached
		rescue => error
			puts "#{error.message}"
		end

		expire_time=24*60

		if data['offers'].nil?
			url=Pumatra.settings.environment_vars[:das_url]+"/offers.json?"
			data['identifiers'].each do |type, ids|
				Array(ids).each do |id|
					send_type=type
					if send_type=='gtin-14'
						id=id.to_i
						if id.to_s.size<=12
							send_type='upc'
						elsif id.to_s.size<=13
							send_type='ean'
						end
					end
					url+="&" if url.last!="?"
					url+="#{URI.escape(send_type)}[]=#{URI.escape(id.to_s)}"
				end
			end

			uri = URI.parse(url)
			response = Pumatra.settings.http.request uri

			offers=JSON.parse(response.body)
			
			offers['products'].each do |prod|
				prod['offers'].each do |key, offer|
					expire_interval=((DateTime.parse(offer['expiration']) - DateTime.parse(Time.now.to_s))*24*60).to_i
					expire_time=expire_interval if expire_interval<expire_time
				end
				if data['offers'].nil?
					data['offers']=prod['offers']
				else
					data['offers'].merge! prod['offers']
				end
			end
		end

		begin
			#expire_time=10 if expire_time<10
			Pumatra.settings.memcached.with do |conn|
				conn.set "#{self.id.to_s}/offers", data['offers'], expire_time.minutes
			end if Pumatra.settings.memcached
		rescue => error
			puts "#{error.message}"
		end

		if options['amazon_tag']
			if data['offers'] && data['offers']["Amazon"]
				data['offers']["Amazon"]['urls'].each do |key, target_url|
					data['offers']["Amazon"]['urls'][key]=target_url.gsub('ecatapultifr-20', options['amazon_tag'])
				end
			end
		end
		
		return data
	end

	
	def self.parse_das_product(product_data, id_type, id, source_name)
		product=nil
		product_data['products'].each do |prod|
			if id_type=='upc'
				product=prod if prod['identifiers'][id_type] && (Array(prod['identifiers'][id_type]).map{|x| x.to_i}.include? id.to_i)
			else
				product=prod if prod['identifiers'][id_type] && (Array(prod['identifiers'][id_type]).include? id)
			end
		end

		if product.nil?
			return nil
			#product=product_data['products'].first
		end

		if product['identifiers']['upc']
			product['identifiers']['upc']=product['identifiers']['upc'].to_i if product['identifiers']['upc'].class==String
			product['identifiers']['upc']=product['identifiers']['upc'].map{|x| x.to_i} if product['identifiers']['upc'].class==Array
		end

		if product['categories'].class==Array
			product['categories'].each_with_index do |cat, i|
				product['categories'][i]+="<#{source_name}"
			end
		elsif product['categories']!=''
			product['categories']+="<#{source_name}"
		else
			product['categories']+=source_name
		end

		product['attributes']=product['attributes'].select{|k, v| ['MPN'].include? k.to_s}

		return product
	end

	def self.import_product_by_id(id_type, id, reimport=false)
		existing_product=Product.unscoped.find_by_indentifers({id_type=>id})
		if existing_product.size>0 && existing_product.first.status=='importing'
			id=existing_product.first.id
			existing_product=Product.unscoped.find(id)
			start=Time.now
			while existing_product.status=='importing' && (Time.now-start)<10 do
				sleep 0.5
				existing_product=Product.unscoped.find(id)
			end
		else
			if existing_product.size>0
				existing_product=existing_product.first 
				if existing_product.status=='import_failed'
					existing_product.status='importing'
				elsif reimport
					existing_product.status='reimporting'
				else
					return existing_product
				end
			elsif existing_product.size==0
				existing_product=Product.create({:status=>'importing'})
				existing_product.update_relelated_data({'identifiers'=>{id_type=>id}})
			end

			url=Pumatra.settings.environment_vars[:das_url]+"/vendors.json"
			uri = URI.parse(url)
			response = Pumatra.settings.http.request uri
			#response = Net::HTTP.get_response(URI(url))
			vendors=JSON.parse(response.body)

			if id_type=='gtin-14'
				if id.to_i.to_s.size<=12
					id_type='upc'
					id=id.to_i.to_s
				elsif id.to_i.to_s.size<=13
					id_type='ean'
					id=id.to_i.to_s
				end
			end
			
			id_type=URI.escape(id_type)
			id=URI.escape(id.to_s)

			#Try Amazon if ASIN UPC
			if ['asin', 'upc'].include? id_type
				source_name='Amazon'
				url=Pumatra.settings.environment_vars[:das_url]+"/vendors/#{vendors['sources'].select{|x| x['name']=='Amazon'}.first['id']}/products.json?#{id_type}[]=#{id}"
				uri = URI.parse(url)
				response = Pumatra.settings.http.request uri
				#response = Net::HTTP.get_response(URI(url))
				product_data=JSON.parse(response.body)
				if product_data['products'] && product_data['products'].size>0
					product=Product.parse_das_product(product_data, id_type,id, source_name)
				end
			end
			
			if ['price_grabber_sku'].include? id_type
				source_name='PriceGrabber'
				url=Pumatra.settings.environment_vars[:das_url]+"/vendors/#{vendors['sources'].select{|x| x['name']=='PriceGrabber'}.first['id']}/products.json?#{id_type}[]=#{id}"
				uri = URI.parse(url)
				response = Pumatra.settings.http.request uri
				#response = Net::HTTP.get_response(URI(url))
				product_data=JSON.parse(response.body)

				if product_data['products'] && product_data['products'].size>0
					pg_product=Product.parse_das_product(product_data, id_type,id, source_name)
				end

				if pg_product && pg_product['identifiers']
					ids={}
					pg_product['identifiers'].each do |id_type, id_array|
						id_type=Identifier.format_type(id_type)
						ids[id_type]=Array(id_array).map{|x| Identifier.validate(id_type, x)}
					end
					pg_product['identifiers']=ids
				end

				products=Product.unscoped.includes(:identifiers).where(identifiers:{name:'gtin-14',value:pg_product['identifiers']['gtin-14']}) if pg_product && pg_product['identifiers'] && pg_product['identifiers']['gtin-14']

				if products && products.size>0
					existing_product.destroy
					product=products.first	
					ids=product.identifiers_hash
					ids['price_grabber_sku']=pg_product['identifiers']['price_grabber_sku']
					categories=product.categories_array+Array(pg_product['categories'])
					product=product.update_relelated_data({'identifiers'=>ids, 'categories'=>categories})
					return product
				elsif pg_product && pg_product['identifiers'] && pg_product['identifiers']['gtin-14']
					if id_type=='gtin-14'
						if id.to_i.to_s.size<=12
							id_type='upc'
							id=id.to_i.to_s
						elsif id.to_i.to_s.size<=13
							id_type='ean'
							id=id.to_i.to_s
						end
					end

					url=Pumatra.settings.environment_vars[:das_url]+"/vendors/#{vendors['sources'].select{|x| x['name']=='Amazon'}.first['id']}/products.json?"
					go=false
					upc=nil
					pg_product['identifiers']['gtin-14'].each do |ids|
						Array(ids).each do |id|
							if id.to_i.to_s.size<=12
								url+="&" if url.last!="?"
								url+="upc[]=#{id}"
								upc=id
								go=true
							end
						end
					end
					if go
						uri = URI.parse(url)
						response = Pumatra.settings.http.request uri
						#response = Net::HTTP.get_response(URI(url))
						product_data=JSON.parse(response.body)
						if product_data['products'] && product_data['products'].size>0
							product=Product.parse_das_product(product_data, 'upc', upc, 'Amazon')
							if !product.nil?
								product['identifiers']['price_grabber_sku']=pg_product['identifiers']['price_grabber_sku']
								product['categories']=Array(product['categories'])+Array(pg_product['categories'])
							else
								product=pg_product
							end
						else
							product=pg_product
						end					
					else
						product=pg_product
					end
				else
					product=pg_product
				end
			end
			if product
				prod_data=product.select{|k,v| Product.attribute_names.include? k.to_s}
				prod_data['status']='imported'
				existing_product.update(prod_data)
				existing_product.update_relelated_data(product.select{|k,v| ['attributes', 'categories', 'identifiers'].include? k.to_s})
			else
				prod_data={'status'=>'import_failed'}
				existing_product.update(prod_data)
			end
		end
		
		return existing_product
	end

	def categories_array
		data=[]
		self.categories.each do |c|
			data<<c.self_and_ancestors.collect{|cat| cat.name}.join(">")
		end
		data
	end

	def awards_hash
		{}.tap{ |h| self.awards.each{ |a| h[a.key] ? h[a.key] = h[a.key].class==Array ? h[a.key]<<{'name'=>a.name, 'review_url'=>a.review_url, 'date_awarded'=>a.date_awarded, 'image_url'=>a.image_url} : h[a.key]<<{'name'=>a.name, 'review_url'=>a.review_url, 'date_awarded'=>a.date_awarded, 'image_url'=>a.image_url} : h[a.key] = {'name'=>a.name, 'review_url'=>a.review_url, 'date_awarded'=>a.date_awarded, 'image_url'=>a.image_url} } }
	end

	def specs_hash
		{}.tap{ |h| self.product_specs.each{ |a| h[a.spec_type.name] = "#{a.value} #{a.units}".rstrip  if !a.value.nil?} }
	end

	def attributes_hash
		{}.tap{ |h| self.product_attributes.each{ |a| h[a.attribute_type.name] = a.value if !a.value.nil?} }
	end

	def identifiers_hash
		{}.tap{ |h| self.identifiers.each{ |a| h[a.name] = h[a.name].nil? ? a.value : h[a.name].class==Array ? h[a.name]<<a.value : [h[a.name],a.value]  if !a.value.nil?} }
	end
	
	def properties_hash
		self.properties.collect{ |p| p.name }
	end

	def update_relelated_data(params)
		self.product_specs.destroy_all if params['specs']
		params['specs'].each do |spec, value|
			spec_type=SpecType.find_or_create_by('name'=>spec.to_s.gsub(/\s./) {|match| match.gsub(/\s/,"").upcase})
			spec_value= value.class==Hash ? value['value'].to_f : value.to_f
			spec_units= value.class==Hash ? value['units'].lstrip.rstrip : value.match(/[0-9\.]*(.*)/)[1].lstrip.rstrip if value.class==String
			prod_spec=self.product_specs.build({'value'=>spec_value, 'units'=>spec_units})
			prod_spec.spec_type=spec_type
			prod_spec.save
		end if params['specs']

		self.product_attributes.destroy_all if params['attributes']
		params['attributes'].each do |name, value|
			attribute_type=AttributeType.find_or_create_by('name'=>name.to_s.gsub(/\s./) {|match| match.gsub(/\s/,"").upcase})
			prod_attribute=self.product_attributes.build({'value'=>value[0...255]})
			prod_attribute.attribute_type=attribute_type
			prod_attribute.save
		end if params['attributes']

		self.product_properties.destroy_all if params['properties']
		params['properties'].each do |name, value|
			property=Property.find_or_create_by('name'=>name.to_s.gsub(/\s./) {|match| match.gsub(/\s/,"").upcase})
			prod_prop=self.product_properties.build()
			prod_prop.property=property
			prod_prop.save
		end if params['properties']

		self.categories.destroy_all if params['categories']
		Array(params['categories']).each do |value|
			value=value.split(">") if value.class != Array
			value=value.first.split("<").reverse if value.size==1
			last=nil
			value.each do |c|
				last = last.nil? ? Category.find_or_create_by('name'=>c, 'parent_id'=>nil) : Category.find_or_create_by('name'=>c, 'parent_id'=>last.id)
			end
			self.categories<<last
		end if params['categories']

		self.product_tags.destroy_all if params['tags']
		params['tags'].each do |tag|
			tag_value=tag.downcase.gsub(/[^0-9a-z]/, "")
			self.tags<<Tag.find_or_create_by('value'=>tag_value) do |t|
				t.name=tag
			end
		end if params['tags']

		self.identifiers.destroy_all if params['identifiers']
		params['identifiers'].each do |key, value|
			key=Identifier.format_type(key)
			values= value.class!=Array ? [value] : value
			values.each do |val|
				self.identifiers<<Identifier.find_or_create_by(name:key, value:Identifier.validate(key, val))
			end
		end if params['identifiers']

		self.awards.destroy_all if params['awards']
		params['awards'].each do |key, award|
			self.awards.create({'name'=>award['name'], 'review_url'=>award['review_url'], 'date_awarded'=>award['date_awarded'],'key'=>key})
		end if params['awards']
		
		self.save
		return self
	end

	def find_similar_products
		arr = []
		products = {}
		attr_types = []

		self.product_attributes.map do |attribute|
			attr_types << { :id => attribute.attribute_type_id, :value => attribute.value}
		end

		attr_types.each do |a|
			Product.find_by_sql([
				'SELECT
				p.id,
				(1/(LEVENSHTEIN(?,pa.value)+1)) * at.weight AS weight
				FROM products p
				LEFT JOIN product_attributes AS pa ON p.id = pa.product_id
				LEFT JOIN attribute_types AS at ON pa.attribute_type_id = at.id
				WHERE pa.attribute_type_id in (?) && p.id != ?
				GROUP BY id',a[:value],a[:id],self.id]
			).each do |entry|
				products[entry.id]=0 if products[entry.id].nil? 
				products[entry.id]+=entry.weight
			end
		end

		list = products.sort_by {|k,v| v}.reverse

		list.each_with_index do |l,i|
			if i > 10
				break
			else
				arr << l[0]
			end
		end

		Product.where("id in (?) ", arr)
	end
	
	def find_related_products
		similar = []
		model = attributes_hash['Model'].nil? ? nil : attributes_hash['Model']
		label = attributes_hash['Label'].nil? ? nil : attributes_hash['Label']
		display = specs_hash['Display'].nil? ? nil : specs_hash['Display']

		if !model.nil?
			similar.push("%#{model}%")
		end

		if !label.nil?
			similar.push("%#{label}%")
		end

		if !display.nil?
			similar.push("%#{display}%")
		end
		
		findConditionStr = "id != ? && ("

		similar.each_with_index do |i,index|
			if similar.length > 1 && index != similar.length - 1
				findConditionStr += "name like ? || "
			else
				findConditionStr += "name like ? "
			end
		end
		
		return Product.where([findConditionStr += ")",self.id].concat(similar))
	end

	after_commit :clear_cache
	def clear_cache
        cache_enabled = Pumatra.settings.respond_to?(:cache_enabled) ? Pumatra.settings.send(:cache_enabled) : false
        cache_output_dir = Pumatra.settings.send(:cache_output_dir)  if Pumatra.settings.respond_to?(:cache_output_dir)
        if (cache_enabled && Pumatra.settings.send(:environment) == Pumatra.settings.cache_environment) 
          cache_output_dir = Pumatra.settings.send(:cache_output_dir)
          system("rm #{cache_output_dir}/products/#{id}.*")
          cache_exp = File.file?(cache_output_dir+'/expire.dat') ? Marshal.load(File.read(cache_output_dir+'/expire.dat')) : {}
          cache_exp.each do |filename, date|
            if filename.match("products/#{id}")
              system("rm #{filename}")
              cache_exp.delete(filename)
            end
          end
          File.open(cache_output_dir+'/expire.dat', 'w') {
            |f| f.write(Marshal.dump(cache_exp))
          }
        end
	end

end