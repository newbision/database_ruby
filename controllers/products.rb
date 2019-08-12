# encoding: utf-8
class Pumatra < Sinatra::Base
	respond_to :html, :json, :xml
	
	before /^\/products/ do
		params['product']['identifiers'].each do |id_type, id_array|
			id_type=Identifier.format_type(id_type)
			params['product']['identifiers'][id_type]=Array(id_array).map{|x| Identifier.validate(id_type, x)}
		end if params['product'] && params['identifiers']
	end

	get "/products/stats" do
 		data={counts:{}}
 		data[:counts][:products]=Product.group(:status).count
 		data[:counts][:identifiers]=Identifier.all.count
 		data[:counts][:categories]=Category.all.count
		data[:counts][:orphaned]={}
 		data[:counts][:orphaned][:products]=Product.joins('LEFT JOIN identifiers ON "identifiers"."product_id" = "products"."id"').where('identifiers.id IS NULL').count
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/products" do
 		data={products:[]}
 		products = []

 		params[:page]||=1
 		params[:per_page]||=10

 		products = Product.search(params)

 		data[:products_pagination] = {:page =>  params[:page].present? ? params[:page] : params[:page] = "1",:total_pages => products.total_pages.to_s}

 		products.each do |product|
 			data[:products] << product.deep_hash()
 		end
		
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/products/?:id_type?/:id/similar_products" do
		if params[:id_type].nil?
 			product=Product.find(params[:id])
 		else
 			params[:id]=params[:id].to_i if params[:id_type]=='upc'
 			product=Product.includes(:identifiers).where(identifiers:{name:params[:id_type],value:params[:id]}).first
 		end
		
		products=product.find_similar_products
		data = {products:[]}
		products.each do |product|
 			data[:products] << product.deep_hash({:amazon_tag=>params[:amazon_tag]})
 		end
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	
	post "/products/similar_products" do
		product = Product.new
		product.setValues(productHash.select{|k,v| Product.attribute_names.include? k.to_s})
		products=product.find_similar_products
		data = {products:[]}
		products.each do |product|
 			data[:products] << product.deep_hash({:amazon_tag=>params[:amazon_tag]})
 		end
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
	
	get "/products/?:id_type?/:id/related_products" do
		if params[:id_type].nil?
 			product=Product.find(params[:id])
 		else
 			params[:id]=params[:id].to_i if params[:id_type]=='upc'
 			product=Product.includes(:identifiers).where(identifiers:{name:params[:id_type],value:params[:id]}).first
 		end

		data = { products: product ? product.find_related_products : []}
		
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	post "/products/related_products" do
		productHash = params[:product]
		model = productHash[:model] ? productHash[:model] : ''
		product = Product.new
		product.setValues(productHash.select{|k,v| Product.attribute_names.include? k.to_s})
		
		data = { products: product ? product.find_related_products : []}
		
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	#Import Product 
	get "/products/:id_type/:id/import" do

		params[:id_type]=Identifier.format_type(params[:id_type])
		params[:id]=Identifier.validate(params[:id_type], params[:id])


 		product=Product.import_product_by_id(params[:id_type],params[:id])

 		data={products:[product.deep_hash()]}

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	#Get offers 
	get "/products/?:id_type?/:id/offers" do
		if params['id']
			if params['id_type']
				params['id_type']=Identifier.format_type(params['id_type'])
				params['id']=Identifier.validate(params['id_type'], params['id'])
			end
		end

		if params[:id_type].nil?
 			begin
 				products=[Product.unscoped.includes(:identifiers).imported.find(params[:id])]
 			rescue ActiveRecord::RecordNotFound => e
 				products=[]
 				status 404
 				data={error:{message:"Product #{params[:id_type] ? params[:id_type] : 'id'} #{params[:id]} Not Found"}}
 			end
 		else
 			products=Product.unscoped.imported.joins(:identifiers).where(identifiers:{name:params[:id_type],value:params[:id]})#.includes(:identifiers)
 		end

 		if products.size==0 && params[:id_type]
 			products=[]
 			product=Product.import_product_by_id(params[:id_type],params[:id])
 			products<<product if product
 		end

		if products.size == 0
			status 404
 			data={error:{message:"Product #{params[:id_type] ? params[:id_type] : 'id'} #{params[:id]} Not Found"}}
 		else
 			options={}
			options['amazon_tag']=params['amazon_tag'] if params['amazon_tag']
			data={products:products.map{|x| x.get_offers(options)}}
 		end

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
	
	#Gets Product
	get "/products/?:id_type?/:id" do
 		if params['id']
			if params['id_type']
				params['id_type']=Identifier.format_type(params['id_type'])
				params['id']=Identifier.validate(params['id_type'], params['id'])
			end
		end
		
 		if params[:id_type].nil?
 			begin
				products=[Product.find(params[:id])]
			rescue ActiveRecord::RecordNotFound => e
				products=[]
				status 404
				data={error:{message:"Product #{params[:id]} Not Found"}}
			end
 		else
 			products=Product.joins(:identifiers).where(identifiers:{name:params[:id_type],value:params[:id]})
 		end
 		
 		if products.size>0
 			if params[:id_type]=='temnos_id'
 				data={products:Temnos.find_product('temnos_id', params[:id])}
 			else
 				#DAS
 			end
  		end
 		
 		if products.size == 0
 			status 404
 			data={error:{message:"Product #{params[:id_type] ? params[:id_type] : 'id'} #{params[:id]} Not Found"}}
 		else
 			data={products:products.map{|x| x.deep_hash()}} if data.nil?
 		end

		respond_to do |f|
			f.json { json_cache data, :encoder => :to_json, :content_type => :js, :expire=>1}
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end	

	def validate_name(param)
		return param.empty? ? "Name must cannot be blank" : nil
	end

	#Create New
	add_validated_handler :POST, "/products/:id", {
		params:{
	  		product:{
	  			type:'hash',
	  			keys:{
	  				name:{required:true, desc:'product name', type:'string', custom_validator:'validate_name'},
		  			short_description:{type:'string'},
		  			tags:{type:'array', accepted_values:'string'},
		  			attributes:{type:'hash', accepted_values:[{type:'string'}]},
		  			awards:{type:'hash', accepted_values:[{type:'string'}]},
		  			specs:{type:'hash', accepted_values:[{type:'hash', 
		  													keys:{units:{required:true, type:'string'}, 
		  															value:{required:true, type:'float'}
		  														}
		  													},
		  												{type:'string'}
		  												]},
		  			identifiers:{type:'hash', accepted_values:[{type:'array', accepted_values:'string'}, {type:'string'}]},
		  			categories:{type:'array', accepted_values:'string'}
		  		}
	  		}
	  	}
	 }
		
	#Partial Update
	post "/products/:id" do
		product=Product.update(params[:id], params[:product].select{|k,v| Product.attribute_names.include? k.to_s})
		
		product.update_relelated_data(params[:product])
		
		data={product:product.deep_hash()}
		
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
	
	#Full Update
	put "/products/:id" do
		product=Product.update(params[:id], params[:product].select{|k,v| Product.attribute_names.include? k.to_s})
		product.product_specs=[]
		product.product_attributes=[]
		product.tags=[]
		product.update_relelated_data(params[:product])

		data={product:product.deep_hash}

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end


	post "/products" do
		if params[:product]
			product=Product.create(params[:product].select{|k,v| Product.attribute_names.include? k.to_s})
			
			product.update_relelated_data(params[:product])
			
			data={product:product.deep_hash}
		else
			data={errors:[{
					message:"No Product Info Specified"
				}]
			}
		end

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
	
	#Delete a product
	delete "/products/:id" do
		begin
			product = Product.find(params[:id])
		rescue ActiveRecord::RecordNotFound => e
			status 404
			data={error:{message:"Product #{params[:id]} Not Found"}}
		end
		
		if product && product.destroy
			data={message:"Deleted Product #{params[:id]}"}
		elsif product.nil?
			status 404
 			data={error:{message:"Product #{params[:id]} Not Found"}}
		else
			status=500
			data={error:{message:"Error Deleting Product #{params[:id]}"}}
		end
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
end
