class Pumatra < Sinatra::Base
	respond_to :html, :json, :xml


	get '/categories/stats2' do
		data={}

		counts=ProductCategory.group(:category_id).count(:all)

		categories=Category.all.each_with_object({}) do |x, memo|
		  memo[x.id] = {id:x.id, name:x.name, parent_id:x.parent_id}
		end

		data=categories

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end

	end



	get '/categories/stats' do
		data={}

		counts=ProductCategory.group(:category_id).count(:all)

		#categories=Category.all.sort('lft').each_with_object({}) do |x, memo|
		#  memo[x.id] = {id:x.id, name:x.name, parent_id:x.parent_id, direct_products:counts[x.id] ? counts[x.id] : 0, total_products:0 }
		#end

		categories_nested_hash={}

		def find2(categories, hash, id)
			temphash = {}
			found = false
			categories.each do |tid, cat|
				if cat[:parent_id] == id
					temphash[cat[:id]] = cat
					categories.delete cat[:id]
					tempchild = find2(categories, temphash, cat[:id])
					temphash[cat[:id]][:children] = tempchild if !tempchild.empty?
					found = true
				end
			end
			return temphash
		end

		def find(cat, hash)
			found=false
			if !hash[cat[:parent_id]].nil?
				hash[cat[:parent_id]][:children]={} if hash[cat[:parent_id]][:children].nil?
				hash[cat[:parent_id]][:children][cat[:id]]=cat
				found=true
			else
				hash.each do |k, v|
					hash[k][:children], found=find(cat, v[:children]) if !v[:children].nil?
					return hash, found if found
				end
			end
			return hash, found
		end

		if params[:id].nil?
			categories.each do |id, cat|
				if cat[:parent_id].nil?
					categories_nested_hash[id]=cat
					categories.delete id
				end
			end
			while categories.size>0 do
				categories.each do |id, cat|
					categories_nested_hash, found=find(cat,categories_nested_hash)
					categories.delete id if found
				end
			end
		else
			id = params[:id].to_i
			categories_nested_hash[id] = categories[id]
			categories.delete id

			temp = find2(categories,categories_nested_hash,id)

			categories_nested_hash[id][:children] = temp if !temp.empty?
			
		end

		def sum(cat)
			sum=0
			cat[:children].each do |k, child_cat|
				sum+=sum(child_cat)
			end if cat[:children]
			sum+=cat[:direct_products] ? cat[:direct_products] : 0
			cat[:total_products]=sum
			return sum
		# Category.all.order('lft').find_each(batch_size: 50) do |cat|
		# 	if cat.parent_id
		# 		if categories_nested_hash[cat.parent_id]
		# 			categories_nested_hash[cat.parent_id][:children]={} if categories_nested_hash[cat.parent_id][:children].nil?
		# 			categories_nested_hash[cat.parent_id][:children][cat.id]={id:cat.id, name:cat.name, parent_id:cat.parent_id, direct_products:counts[cat.id] ? counts[cat.id] : 0, total_products:0 }
		# 		else
		# 			last_id=cat.parent_id-1
		# 			while !(categories_nested_hash[last_id] && categories_nested_hash[last_id][:children][cat.parent_id]) do
		# 				last_id=last_id-1
		# 			end
		# 			if categories_nested_hash[last_id] && categories_nested_hash[last_id][:children][cat.parent_id]
		# 				categories_nested_hash[last_id][:children][cat.parent_id][:children]={} if categories_nested_hash[last_id][:children][cat.parent_id][:children].nil?
		# 				categories_nested_hash[last_id][:children][cat.parent_id][:children][cat.id]={id:cat.id, name:cat.name, parent_id:cat.parent_id, direct_products:counts[cat.id] ? counts[cat.id] : 0, total_products:0 }
		# 			end
		# 		end
		# 	else
		# 		categories_nested_hash[cat.id]={id:cat.id, name:cat.name, parent_id:cat.parent_id, direct_products:counts[cat.id] ? counts[cat.id] : 0, total_products:0 }
		# 	end
		end

		categories_nested_hash.each do |id, cat|
			sum(cat)
		end

		data=categories_nested_hash

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get '/categories/:id' do 
		cat=Category.find(params[:id])
		data={id:cat.id,name:cat.name,parent_id:cat.parent_id, children:cat.children.map{|x| x.id}, path:cat.self_and_ancestors.map{|x| x.name}.join('>')}
		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end

	get '/categories' do 
		data=Category.all

		respond_to do |f|
			f.json { json data, :encoder => :to_json, :content_type => :js }
			f.xml { data.to_xml }
			f.html { erb :"templates/status", :layout => :"layouts/main", :locals => { data:data} }
		end
	end
end