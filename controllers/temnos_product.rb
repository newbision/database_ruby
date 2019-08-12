class Pumatra < Sinatra::Base
	respond_to :html, :json, :xml
	
	get "/temnos/products/search" do
		data={products:Temnos.search(params[:keywords])}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/temnos/products/:identifier_type" do
		products=Temnos.find_products(params[:identifier_type], params[:identifiers])
		data={products:products}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/temnos/products/?:identifier_type?/:identifier" do
		params[:identifier_type]='temnos_id' if params[:identifier_type].nil?
		data={products:Temnos.find_product(params[:identifier_type], params[:identifier])}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/temnos/products/?:identifier_type?/:identifier/raw" do
		params[:identifier_type]='temnos_id' if params[:identifier_type].nil?
		products=Temnos.find_product_raw(params[:identifier_type], params[:identifier])
		data={products:products}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get "/temnos/products/:identifier_type/:identifier/import" do
		product=Temnos.find_product(params[:identifier_type], params[:identifier])
		product=product.first
		p=Product.find_by_indentifers(product[:identifiers])
		
		if p.size==0
			p=Product.create(product.select{|k,v| Product.attribute_names.include? k.to_s})
			p.update_relelated_data(product)
		else
			p=p.first
		end
		
		data={products:[p.deep_hash()]}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
end