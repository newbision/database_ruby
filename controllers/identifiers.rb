class Pumatra < Sinatra::Base
	respond_to :html, :json, :xml

	get '/identifiers' do 
		data=Identifier.distinct(:name).pluck(:name)

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	delete '/identifiers/:name' do 
		if !(['asin', 'gtin-14', 'isbn', 'price_grabber_sku'].include? params[:name])
			data={count:Identifier.where(name:params[:name]).destroy_all.count}
		else
			status=403
			data={error:{message:"Delete identifier #{params[:name]} not allowed"}}
		end

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

end