require 'rubygems'
require 'bunny'
require 'json'
require 'sqlite3'
require 'base64'

conn = Bunny.new
conn.start

ch = conn.create_channel
ch.prefetch(0,true)
qgu  = ch.queue("getUpdated", :durable=>true, :autodelete=>false)
qfc  = ch.queue("formatContent", :durable=>true, :autodelete=>false)
qfp  = ch.queue("fluctuatePrice", :durable=>true, :autodelete=>false)
x  = ch.default_exchange

#setup db
db = SQLite3::Database.new( "./demo.db" )
db.execute("PRAGMA default_synchronous=OFF")
prng = Random.new

#loop on workers
while true do

    #FORMAT CONTENT TO 'STANDARD' OF ALL CAPS
    qfc.subscribe do |delivery_info, metadata, payload|
        puts "formatContent"
        pl = JSON.parse(payload)

        #change .sku for each product to uppercase
        pl["return_value"]["products"].each_with_index do |value, key|
            pl["return_value"]["products"][key]['sku'] = pl["return_value"]["products"][key]['sku'].upcase
            pl["return_value"]["products"][key]['price'] = pl["return_value"]["products"][key]['price'].round(2)
        end

        #publish response back to mq
        out=JSON.generate(pl)
        x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
    end

    #GET PRODUCTS UPDATED ON OR AFTER 'SINCE'
    qgu.subscribe do |delivery_info, metadata, payload|
        puts "getUpdated"
        pl = JSON.parse(payload)

        #fetch updated product info from db
        rows=[]
        if pl["initial_input"]["since"].to_i == 0
            rows = db.execute( "SELECT * FROM productlog GROUP by sku order by stamp desc" )
        else
            rows = db.execute( "SELECT p.*,
	(SELECT lp.price FROM productlog lp where lp.stamp<p.stamp AND lp.sku=p.sku ORDER BY lp.stamp DESC LIMIT 0,1) as last_price
    FROM productlog p WHERE p.stamp >= ?", pl["initial_input"]["since"].to_i/1000 )
        end

        data=[]
        rows.each do |row|
            data << {
                :sku => row[0],
                :price => row[1],
                :inventory => row[2],
                :last_price => row[4]
            }
        end
        pl['return_value']['products']=data

        #truncate price log to last 500 if we have more than 5000 entries
        count = db.get_first_value("select count(*) from productlog")
        if count > 5000
            db.execute("delete from productlog where stamp not in (select stamp from productlog order by stamp desc limit 500)")
        end

        #publish response back to mq
        out=JSON.generate(pl)
        x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
    end

    #FLUCTUATE PRICE AND INVENTORY
    count=0
    db.transaction do |db|
        qfp.subscribe do |delivery_info, metadata, payload|
            puts "fluctuatePrice"
            pl = JSON.parse(payload)

            #change prices and inv around in db
            inv = prng.rand(100)-25
            price = prng.rand()*200
            sku = "P"+Base64.encode64(prng.rand(101..200).to_s).downcase.reverse.sub("\n","")
            db.execute("INSERT INTO productlog VALUES (?,?,?,strftime('%s','now'))",
                sku, price, inv
            )
            count+=1

            #set return val
            pl['return_value']['success']=true

            #publish response back to mq
            out=JSON.generate(pl)
            x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
        end
    end
    if count>0
        puts count
    end

    sleep 0.001
end

conn.close
