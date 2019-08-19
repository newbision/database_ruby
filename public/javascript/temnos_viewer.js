function load(url, callback) {
        var xhr;
        if(typeof XMLHttpRequest !== 'undefined') xhr = new XMLHttpRequest();
        else {
            var versions = ["MSXML2.XmlHttp.5.0", 
                            "MSXML2.XmlHttp.4.0",
                            "MSXML2.XmlHttp.3.0", 
                            "MSXML2.XmlHttp.2.0",
                            "Microsoft.XmlHttp"]
             for(var i = 0, len = versions.length; i < len; i++) {
                try {
                    xhr = new ActiveXObject(versions[i]);
                    break;
                }
                catch(e){}
             } // end for
        }
        xhr.onreadystatechange = ensureReadiness;
        function ensureReadiness() {
            if(xhr.readyState < 4) {
                return;
            }
            if(xhr.status !== 200) {
                return;
            }
            // all is well  
            if(xhr.readyState === 4) {
                callback(xhr);
            }           
        }
        xhr.open('GET', url, true);
        xhr.send('');
}


product_data={};

function get_json(url, callback){
    load(url,function (xhr){
        obj = JSON.parse(xhr.responseText);
        
        if(obj.hasOwnProperty('products')){
           for (var i = 0; i < obj.products.length; ++i)
            for (var key in obj.products[i].identifiers) {
               product_data[key+"_"+obj.products[i].identifiers[key]]=obj.products[i];
            }
        }

        callback(obj)
    });
}

function get_json_no_cache(url, callback){
    load(url,function (xhr){
        obj = JSON.parse(xhr.responseText);
        
        /*if(obj.hasOwnProperty('products')){
           for (var i = 0; i < obj.products.length; ++i)
            for (var key in obj.products[i].identifiers) {
               product_data[key+"_"+obj.products[i].identifiers[key]]=obj.products[i];
            }
        }*/

        callback(obj)
    });
}

function keyword_search(keyword, callback){
    get_json("/temnos/products/search.json?keywords="+keyword, callback)
}

function lookup_product_raw(id_type,id, callback){
     if(id_type=='temnos_id'){
        get_json("/temnos/products/temnos_id/"+id+"/raw.json", callback)
    }else{
        get_json("/temnos/products/"+id_type+"/"+id+"/raw.json", callback)
    } 
}

function price_product(id_type, id, callback){
    get_json_no_cache('http://products.svc.int.purch.com/das/offers.json?platform[]=app&'+id_type+'[]='+id+'', function(p){
       callback(p['products'][0])
    });
}

function lookup_product(id_type, id, callback){
    if(typeof product_data[id_type+'_'+id] === 'undefined'){
        product_data[id_type+'_'+id]='pending';
        if(id_type=='temnos_id'){
            get_json("/temnos/products/temnos_id/"+id+".json", callback)
        }else{
            get_json("/temnos/products/"+id_type+"/"+id+".json", callback)
        }
    }else if(product_data[id_type+'_'+id]!='pending'){
        callback({'products':[product_data[id_type+'_'+id]]});        
    }   
}

function position_tool_tip(e){
    document.getElementById('tool_tip').style.top=e.clientY+5+window.scrollY+"px";
    document.getElementById('tool_tip').style.left=e.clientX+10+"px";
}

function close_tooltip(){
    document.getElementById('tool_tip').style.display='none';
};

function render_product_name_tool_tip(product){
    document.getElementById('tool_tip').innerHTML=product.short_description;
    document.getElementById('tool_tip').style.display='block';
}

function render_product_list(products){
    cont="";
    for (var i = 0; i < products.length; ++i) {
        cont+='<span class="product_name"><span class="product_id">'+products[i].identifiers['temnos_id']+'</span>: '+products[i].name+'</span><br>';
    }
    if(cont=='')
        cont='No Products Found'
    document.getElementById('popup_cont').innerHTML=cont;
    document.getElementById("bottom_control").innerHTML='Hide';
    document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
    document.getElementById("popup_cont").style.display='block';
    attach_handlers();
}

function render_product_compare(product){
    lookup_product("temnos_id", current_product_id, function(data){render_product_column(data.products[0]);});

    document.getElementById('product_2_name_value').innerHTML=product.name+'<button class="json_view" value="'+product.identifiers['temnos_id']+'" type="button">JSON</button><button class="raw_view" value="'+product.identifiers['temnos_id']+'" type="button">Raw</button>';
    document.getElementById('product_2_desc_value').innerHTML=product.short_description;
    
    ids=''
    for (var key in product.identifiers) {
      ids+='<div><span class="identifier_key">'+key+':</span>'+product.identifiers[key];
      if(key=='upc')
        ids+="<br>"+barcode_html(product.identifiers[key])+"<br>";
      ids+='</div>';
    }
    document.getElementById('product_2_identifiers').innerHTML=ids;

    awards=''
    for (var key in product.awards) {
      awards+='<div><a href="'+product.awards[key].url+'">'+product.awards[key].name+'</a></div>';
    }
    document.getElementById('product_2_awards').innerHTML=awards;


    for (var key in product.attributes) {
        if(document.getElementById('product_2_'+key+'_value')!=null){
            document.getElementById('product_2_'+key+'_value').innerHTML=product.attributes[key];
            document.getElementById('product_2_'+key+'_value').parentNode.className+=' matching'
            if(product.attributes[key]!=current.attributes[key])
                document.getElementById('product_2_'+key+'_value').parentNode.className+=' different'
        }
        else{
             row='<tr id="'+key.replace(/\s+/g, '_').toLowerCase()+'" class="attributes feature missing"><td class="key">'+key+':</td><td class="product_1_value"></td><td id="product_2_'+key+'_value" class="product_2_value">'+product.attributes[key]+'</td></tr>';
             document.getElementById("product_compare").innerHTML+=row;
        }
    }

    for (var key in product.specs) {
        if(document.getElementById('product_2_'+key+'_value')!=null){
            document.getElementById('product_2_'+key+'_value').innerHTML=product.specs[key];
            document.getElementById('product_2_'+key+'_value').parentNode.className+=' matching'
            if(product.specs[key]!=current.specs[key])
                document.getElementById('product_2_'+key+'_value').parentNode.className+=' different'
        }
        else
             document.getElementById("product_compare").innerHTML+='<tr id="'+key.replace(/\s+/g, '_').toLowerCase()+'" class="specs feature missing"><td class="key">'+key+':</td><td class="product_1_value"></td><td id="product_2_'+key+'_value" class="product_2_value">'+product.specs[key]+'</td></tr>';
    }

    for (var key in product.properties) {
        propkey=product.properties[key].replace(/\s+/g, '_').toLowerCase();
        if(document.getElementById('product_2_'+propkey+'_value')!=null){
            document.getElementById('product_2_'+propkey+'_value').innerHTML=product.properties[key];
            document.getElementById('product_2_'+propkey+'_value').parentNode.className+=' matching'
        }
        else
             document.getElementById("product_compare").innerHTML+='<tr id="'+propkey+'" class="properties feature missing"><td class="key"></td><td class="product_1_value"></td><td id="product_2_'+propkey+'_value" class="product_2_value">'+product.properties[key]+'</td></tr>';
    }

    for (var key in product.most_comparable_products) {
      document.getElementById("product_2_most_comparable_products").innerHTML+='<div><span class="most_comparable_products_key">'+(1+parseInt(key))+':</span><span class="product_id">'+product.most_comparable_products[key]+'</span></div>'
    }

    for (var key in product.comparable_products) {
      document.getElementById("product_2_comparable_attributes_products").innerHTML+='<div><span class="product_id">'+key+'</span></div>'
    }

    rows=document.getElementsByClassName('feature');
    new_rows=[];
    while (rows.length>0) {
        new_rows.push(rows[0].cloneNode(true));
        rows[0].parentNode.removeChild(rows[0]);
        //target.parentNode.insertBefore(tmprow, target.nextSibling);
    }

    new_rows.sort(function (a,b){
        if(a.className.indexOf("attributes")>-1 && b.className.indexOf("attributes")<0){
            return -1
        }
        if(b.className.indexOf("attributes")>-1 && a.className.indexOf("attributes")<0){
            return 1
        }

        if(a.className.indexOf("specs")>-1 && b.className.indexOf("specs")<0){
            return -1
        }
        if(b.className.indexOf("specs")>-1 && a.className.indexOf("specs")<0){
            return 1
        }


        if(a.id < b.id)
            return -1;
        if(a.id > b.id)
            return 1;
        return 0;
    })

    if(product_data['temnos_id_'+current_product_id]['comparable_products'] != undefined && product_data['temnos_id_'+current_product_id]['comparable_products'][product['identifiers']['temnos_id']]!=undefined){
        interesting=product_data['temnos_id_'+current_product_id]['comparable_products'][product['identifiers']['temnos_id']].reverse()
        for (var i = 0; i<interesting.length; i++) {
            key=interesting[i].replace(/\s+/g, '_').toLowerCase();
            for (var j = 0; j<new_rows.length; j++) {
               if(new_rows[j].id==key){
                    tmp=new_rows[j]
                    tmp.className+=" compadder"
                    new_rows.splice(j,1)
                    new_rows.unshift(tmp)
               }
            }
        }
    }
    else{

    }
    
    target=document.getElementById('most_comparable_products');
    for (var i = 0; i<new_rows.length; i++) {
        target.parentNode.insertBefore(new_rows[i], target);
    }

    document.getElementById('product_compare').className+=' compare'

    attach_handlers();
    price_product('upc', product.identifiers['upc'], function(p){
        if(p!=undefined){
            offers='';
            for (var key in p['offers']){
                price=0
                if(typeof(p['offers'][key]['price'])=='number'){
                    price=p['offers'][key]['price']
                }
                else{
                    price=p['offers'][key]['price']['current']
                    //Object.keys(p['offers'][key]['price']).forEach(function (k) { 
                    //    if(price==0 || price>p['offers'][key]['price'][k])
                    //        price = p['offers'][key]['price'][k]
                    //})
                }
                offers+="<a target='_blank' href='"+p['offers'][key]['urls']['target_url']+"'>"+key+':'+price+"</a><br>";
            }
            document.getElementById("product_2_price").innerHTML=offers;
            document.getElementById("price").style.display="table-row";
        }
    });
}


function barcode_digit(digit, pos){
    if(pos<=6){
        switch(digit) {
            case 1:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div></div>";
            case 2:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 3:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div></div>";
            case 4:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 5:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div></div>";
            case 6:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 7:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 8:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 9:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div></div>";
            case 0:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div></div>";
        }
    }
    else{ 
        switch(digit) {
            case 1:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
            case 2:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 3:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
            case 4:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 5:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
            case 6:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 7:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 8:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 9:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div></div>";
            case 0:
                return "<div class='bc_digit bc_"+pos+"'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
        }
    }
}

function barcode_html(upc){
    html="<div class='barcode'>"
    html+="<div class='bc_digit bc_ends'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> </div>";
    n = parseInt(upc.split("").reverse().join(""));
    count=0;
    while(n) {
        digit = n % 10;
        n = Math.floor(n/10);
        count+=1;
        html+=barcode_digit(digit, count);
        if(count==6)
             html+="<div class='bc_digit bc_mid'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
    }
    for (var i=12-count; i > 0; i--) {
        console.log(0)
        count+=1;
        html+=barcode_digit(0, count);
        if(count==6)
            html+="<div class='bc_digit bc_mid'><div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div></div>";
    }
    html+="<div class='bc_digit bc_ends'><div class='bc_digit_bit black'></div> <div class='bc_digit_bit white'></div> <div class='bc_digit_bit black'></div> </div>";
    html+="</div>"
    return html
}

current_product_id=null;
current=null;
function render_product_column(product){
    document.getElementById('product_compare').className=''

    current=product;
    table_rows='';
    table_rows+='<thead><div><tr id="name" class="header"><td class="key">Name:</td><td  class="product_1_value">'+product.name+'<button class="json_view" value="'+product.identifiers['temnos_id']+'" type="button">JSON</button><button class="raw_view" value="'+product.identifiers['temnos_id']+'" type="button">Raw</button></td><td id="product_2_name_value" class="product_2_value"></td></tr></div></thead>';
    table_rows+='<tr id="desc"><td class="key">Description:</td><td class="product_1_value">'+product.short_description+'</td><td id="product_2_desc_value" class="product_2_value"></td></tr>';
    table_rows+='<tr id="identifiers"><td class="key">Identifiers:</td><td class="product_1_value">'
    for (var key in product.identifiers) {
      table_rows+='<div><span class="identifier_key">'+key+':</span>'+product.identifiers[key];
      if(key=='temnos_id')
        current_product_id=product.identifiers[key]
      if(key=='upc')
        table_rows+="<br>"+barcode_html(product.identifiers[key])+"<br>";
      table_rows+='</div>';
    }
    table_rows+='</td><td id="product_2_identifiers" class="product_2_value"></td></tr>';

    table_rows+='<tr id="price" style="display:none"><td class="key">Pricing:</td><td id="product_1_price" class="product_2_value"></td><td id="product_2_price" class="product_2_value"></td></tr>';

    table_rows+='<tr id="awards"><td class="key">Awards:</td><td class="product_1_value">'
    for (var key in product.awards) {
      table_rows+='<div><a href="'+product.awards[key].url+'">'+product.awards[key].name+'</a></div>';
    }
    table_rows+='</td><td id="product_2_awards" class="product_2_value"></td></tr>';
    
    for (var key in product.attributes) {
          propkey=key.replace(/\s+/g, '_').toLowerCase();
          table_rows+='<tr id="'+propkey+'" class="attributes feature"><td class="key">'+key+':</td><td class="product_1_value">'+product.attributes[key]+'</td><td id="product_2_'+key+'_value" class="product_2_value"></td></tr>';
    }

    for (var key in product.specs) {
          propkey=key.replace(/\s+/g, '_').toLowerCase();
          table_rows+='<tr id="'+propkey+'" class="specs feature"><td class="key">'+key+':</td><td class="product_1_value">'+product.specs[key]+'</td><td id="product_2_'+key+'_value" class="product_2_value"></td></tr>';
    }
    
    for (var key in product.properties) {
           propkey=product.properties[key].replace(/\s+/g, '_').toLowerCase();
          table_rows+='<tr id="'+propkey+'" class="properties feature"><td class="key"></td><td class="product_1_value">'+product.properties[key]+'</td><td id="product_2_'+propkey+'_value" class="product_2_value"></td></tr>';
    }

    table_rows+='<tr id="most_comparable_products"><td class="key">Top Comparables:</td><td class="">'
    for (var key in product.most_comparable_products) {
      table_rows+='<div><span class="most_comparable_products_key">'+(1+parseInt(key))+':</span><span class="product_id">'+product.most_comparable_products[key]+'</span></div>'
        //lookup_product('temnos_id', product.most_comparable_products[key], function(data){});
    }
    table_rows+='</td><td id="product_2_most_comparable_products" class="product_2_value"></td></tr>';

    table_rows+='<tr id="comparable_attributes_products"><td class="key">Comparable Attribute Products:</td><td class="">'
    for (var key in product.comparable_products) {
      table_rows+='<div><span class="product_id">'+key+'</span></div>'
      //lookup_product('temnos_id', key, function(data){});
    }
    table_rows+='</td><td id="product_2_comparable_attributes_products" class="product_2_value"></td></tr>';

    document.getElementById("product_compare").innerHTML=table_rows;
    attach_handlers();
    price_product('upc', product.identifiers['upc'], function(p){
        if(p!=undefined){
            offers='';
            for (var key in p['offers']){
                price=0
                if(typeof(p['offers'][key]['price'])=='number'){
                    price=p['offers'][key]['price']
                }
                else{
                    price=p['offers'][key]['price']['current']
                    //Object.keys(p['offers'][key]['price']).forEach(function (k) { 
                    //    if(price==0 || price>p['offers'][key]['price'][k])
                    //        price = p['offers'][key]['price'][k]
                    //})
                }
                offers+="<a target='_blank' href='"+p['offers'][key]['urls']['target_url']+"'>"+key+':'+price+"</a><br>";
            }
            document.getElementById("product_1_price").innerHTML=offers;
            document.getElementById("price").style.display="table-row";
        }
    });
}

function render_json(product){
    document.getElementById('popup_cont').innerHTML="<pre class='prettyprint' id='javascript'>"+JSON.stringify(product, null, 4)+"</pre>";
    document.getElementById("bottom_control").innerHTML='Hide';
    document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
    document.getElementById("popup_cont").style.display='block';
    prettyPrint();
}

function load_compare(product){
    if(product == null && current_product_id == null){
        document.getElementById("product_compare").innerHTML='No Product Found';
        return
    }
    if(current_product_id == null){
        current_product_id=product.identifiers['temnos_id'];
        render_product_column(product);
        document.getElementById("popup_cont").style.display='none';
        return
    }
    document.getElementById("prompt").innerHTML='<button id="load_new" value='+product.identifiers['temnos_id']+'>Load New</button><button id="compare" value='+product.identifiers['temnos_id']+'>Compare to Current</button>';
    document.getElementById("prompt").style.display='block';
        
    document.getElementById("load_new").addEventListener("click", function(e) {
       current_product_id=product.identifiers['temnos_id'];
       render_product_column(product);
       document.getElementById("prompt").style.display='none';
       document.getElementById("popup_cont").style.display='none';
       document.getElementById("bottom_control").innerHTML='Show';
    });

    document.getElementById("compare").addEventListener("click", function(e) {
       render_product_compare(product);
       document.getElementById("prompt").style.display='none';
       document.getElementById("popup_cont").style.display='none';
       document.getElementById("bottom_control").innerHTML='Show';
    });
}



function attach_handlers(){
    views=document.getElementsByClassName("json_view");
    for (var i = 0; i < views.length; ++i) {
        views[i].addEventListener("click", function(e) {
           lookup_product("temnos_id", e.target.value, function(data){render_json(data.products[0]);});
           e.stopPropagation();
        });

    }

    views=document.getElementsByClassName("raw_view");
    for (var i = 0; i < views.length; ++i) {
        views[i].addEventListener("click", function(e) {
           lookup_product_raw("temnos_id", e.target.value, function(data){render_json(data.products[0]);});
           e.stopPropagation();
        });

    }

    product_links=document.getElementsByClassName("product_id");
    for (var i = 0; i < product_links.length; ++i) {
        product_links[i].addEventListener("mouseenter", function(e) {
            lookup_product("temnos_id", e.target.innerHTML, function(data){
                position_tool_tip(e);
                render_product_name_tool_tip(data.products[0]);
            });
        });
        product_links[i].addEventListener("mouseleave", function(e) {
            close_tooltip();
        });
        product_links[i].addEventListener("click", function(e) {
           id=e.target.innerHTML
           lookup_product("temnos_id",  id, function(data){load_compare(data.products[0]);});
           e.stopPropagation();
        });

    }
       
};

function ontime_handler_attach(){
    attach_handlers();
    document.getElementById("upc_lookup").addEventListener("click", function(e) {
       lookup_product("upc", document.getElementById("input_box").value, function(data){load_compare(data.products[0]);});
       e.stopPropagation();
    });

    document.getElementById("temnos_id_lookup").addEventListener("click", function(e) {
       lookup_product("temnos_id", document.getElementById("input_box").value, function(data){load_compare(data.products[0]);});
       e.stopPropagation();
    });

    document.getElementById("keyword_search").addEventListener("click", function(e) {
       document.getElementById('popup_cont').innerHTML='Searching For "'+document.getElementById("input_box").value+'"';
       document.getElementById("bottom_control").innerHTML='Hide';
        document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
        document.getElementById("popup_cont").style.display='block';
       keyword_search(document.getElementById("input_box").value, function(data){render_product_list(data.products);});
       e.stopPropagation();
    });

    document.getElementById("body").addEventListener("click", function(e) {
        document.getElementById("bottom_control").innerHTML='Show';
       document.getElementById("popup_cont").style.display='none';
       StopDecode();
       document.getElementById("prompt").style.display='none';
    });

    document.getElementById("bottom_bar").addEventListener("click", function(e) {
        document.getElementById("bottom_control").innerHTML='Hide';
        document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
        document.getElementById("popup_cont").style.display='block';
        e.stopPropagation();
    });

    document.getElementById("bottom_control").addEventListener("click", function(e) {
        if(document.getElementById("popup_cont").style.display=='none'){
            document.getElementById("bottom_control").innerHTML='Hide';
            document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
            document.getElementById("popup_cont").style.display='block';
        }
        else{
            document.getElementById("popup_cont").style.display='none';
            document.getElementById("bottom_control").innerHTML='Show';
        }
        e.stopPropagation();
    });

    document.getElementById("bottom_bar").addEventListener("click", function(e) {
        Decode();
        e.stopPropagation();
    });
}

window.onresize = function(event) {
    document.getElementById("popup_cont").style.maxHeight=window.innerHeight*0.75+'px';
};

function Decode() {
    if(!streaming) return;
    document.getElementById("decode").style.display='none';
    document.getElementById("stopDecode").style.display='inline';
    document.getElementById("prompt").innerHTML='<Canvas id="videoCanvas" width="320" height="240"></Canvas>';
    document.getElementById("prompt").style.display='block';
    JOB.Init();
    var localized = [];
    var streaming = false;
    JOB.StreamCallback = function(result) {
        if(result.length > 0){
            var tempArray = [];
            for(var i = 0; i < result.length; i++) {
                tempArray.push(result[i].Format+" : "+result[i].Value);
                var myArray = /[0-9]{12}$/.exec(result[i].Value);
                lookup_product("upc", myArray[0], function(data){load_compare(data.products[0]);});
                document.getElementById("input_box").value=myArray[0];
            }
        }
    };
    JOB.SetLocalizationCallback(function(result) {
        localized = result;
    });
    JOB.SwitchLocalizationFeedback(true);
    c = document.getElementById("videoCanvas");
    ctx = c.getContext("2d");
    video = document.createElement("video");
    video.width = 640;
    video.height = 480;
    function draw() {
        try {
            ctx.drawImage(video,0,0,c.width,c.height);
            if(localized.length > 0) {
                ctx.beginPath();
                ctx.lineWIdth = "2";
                ctx.strokeStyle="red";
                for(var i = 0; i < localized.length; i++) {
                    ctx.rect(localized[i].x,localized[i].y,localized[i].width,localized[i].height); 
                }
                ctx.stroke();
            }
            setTimeout(draw,20);
        }
        catch (e) {
            if (e.name == "NS_ERROR_NOT_AVAILABLE") {
                    setTimeout(draw,20);
                } else {
                    throw e;
                }
            }
    }
    navigator.getUserMedia = ( navigator.getUserMedia ||
               navigator.webkitGetUserMedia ||
               navigator.mozGetUserMedia ||
               navigator.msGetUserMedia);
    if (navigator.getUserMedia) {
            navigator.getUserMedia (
                {
                video: true,
                audio: true
                },
                function(localMediaStream) {
                video.src = window.URL.createObjectURL(localMediaStream);
                video.play();
                    draw();
                streaming = true;
                },
                function(err) {
                    alert("The following error occured: " + err);
                }
            );
            document.getElementById("decode").style.display='inline';
            
    } else {
            //alert("getUserMedia not supported");
    }
    JOB.DecodeStream(video);
}

function StopDecode() {
    document.getElementById("decode").style.display='inline';
    document.getElementById("stopDecode").style.display='none';
    document.getElementById("prompt").style.display='none';
    JOB.StopStreamDecode();
}

function video_setup(){
    var takePicture = document.querySelector("#Take-Picture"),
    showPicture = document.createElement("img");
    var canvas =document.getElementById("picCanvas");
    var ctx = canvas.getContext("2d");
    JOB.Init();
    JOB.SetImageCallback(function(result) {
        if(result.length > 0){
            var tempArray = [];
            for(var i = 0; i < result.length; i++) {
                tempArray.push([result[i].Format,result[i].Value]);
                var myArray = /[0-9]{12}$/.exec(result[i].Value);
                lookup_product("upc", myArray[0], function(data){load_compare(data.products[0]);});
                document.getElementById("input_box").value=myArray[0];
            }
            console.log(tempArray);
        }else{
            if(result.length === 0) {
                alert("Decoding failed.");
            }
        }
    });
    JOB.PostOrientation = true;
    JOB.OrientationCallback = function(result) {
        canvas.width = result.width;
        canvas.height = result.height;
        var data = ctx.getImageData(0,0,canvas.width,canvas.height);
        for(var i = 0; i < data.data.length; i++) {
            data.data[i] = result.data[i];
        }
        ctx.putImageData(data,0,0);
    };
    JOB.SwitchLocalizationFeedback(true);
    JOB.SetLocalizationCallback(function(result) {
        ctx.beginPath();
        ctx.lineWIdth = "2";
        ctx.strokeStyle="red";
        for(var i = 0; i < result.length; i++) {
            ctx.rect(result[i].x,result[i].y,result[i].width,result[i].height); 
        }
        ctx.stroke();
    });
    if(takePicture && showPicture) {
        takePicture.onchange = function (event) {
            var files = event.target.files;
            if (files && files.length > 0) {
                file = files[0];
                try {
                    var URL = window.URL || window.webkitURL;
                    showPicture.onload = function(event) {
                        //Result.innerHTML="";
                        JOB.DecodeImage(showPicture);
                        URL.revokeObjectURL(showPicture.src);
                    };
                    showPicture.src = URL.createObjectURL(file);
                }
                catch (e) {
                    try {
                        var fileReader = new FileReader();
                        fileReader.onload = function (event) {
                            showPicture.onload = function(event) {
                                //Result.innerHTML="";
                                console.log("filereader");
                                JOB.DecodeImage(showPicture);
                            };
                            showPicture.src = event.target.result;
                        };
                        fileReader.readAsDataURL(file);
                    }
                    catch (e) {
                        alert("Neither createObjectURL or FileReader are supported");
                    }
                }
            }
        };
    } 
    navigator.getUserMedia = ( navigator.getUserMedia ||
               navigator.webkitGetUserMedia ||
               navigator.mozGetUserMedia ||
               navigator.msGetUserMedia);
    if (navigator.getUserMedia) {
            document.getElementById("decode").style.display='inline';
    }
}

document.addEventListener("DOMContentLoaded", ontime_handler_attach);
document.addEventListener("DOMContentLoaded", video_setup);

