require 'rubygems'
require 'bunny'
require 'json'

conn = Bunny.new
conn.start

ch = conn.create_channel
qgu  = ch.queue("getUpdated", :durable=>true, :autodelete=>false)
qfc  = ch.queue("formatContent", :durable=>true, :autodelete=>false)
qfp  = ch.queue("fluctuatePrice", :durable=>true, :autodelete=>false)
x  = ch.default_exchange

while true do
    qfp.subscribe do |delivery_info, metadata, payload|
        pl = JSON.parse(payload)
        #change prices and inv around in db
        pl['data']['success']=true
        out=JSON.generate(pl)
        puts out

        x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
    end

    qfc.subscribe do |delivery_info, metadata, payload|
        pl = JSON.parse(payload)
        #TODO change .sku fr each product to uppercase
        out=JSON.generate(pl)
        puts out

        x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
    end

    qgu.subscribe do |delivery_info, metadata, payload|
        pl = JSON.parse(payload)

        out=JSON.generate(pl)
        puts out

        x.publish(out, :routing_key=>metadata.reply_to, :correlation_id=>metadata.correlation_id)
    end

    sleep 0.01
end

conn.close
