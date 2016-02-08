require 'rack'
require 'openssl'
require 'base64'
require 'json'
require 'net/http'
require 'uri'

class App
    def call(env)
        request = Rack::Request.new env
        response = Rack::Response.new

        case request.path
            when "/get-updates"
                getUpdates(request, response)
        end

        response.status = 200
        response.finish
    end

    def getUpdates(request, response)
        key = 'another_hmac_key'
        group = 'enduser'
        req = '{"since":'+request.params['since']+'}'
        data={}
        data['timestamp']=Time.now.to_i.to_s
        data['message']=req
        digest = OpenSSL::Digest.new('sha512')

        hmacsig = Base64.encode64(OpenSSL::HMAC.hexdigest(digest, key, JSON.generate(data)))
        req64 = Base64.encode64(JSON.generate(data))
        pdata={}
        pdata['signature']=hmacsig
        pdata['data']=req64

        uri = URI.parse("http://localhost:8888/request/products/get-updated")

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.basic_auth(group, "password_ignored")
        request.body=JSON.generate(pdata)
        engineres = http.request(request)

        #just return the results directly
        #TODO check for errors, timeouts, etc
        v=JSON.parse(engineres.body)
        if v['complete']
            response.write JSON.generate(v['return_value'])
        else
            #TODO create a fetch loop for get the complete result
            response.write '{"products":[{"sku":"QWEQWE", "price":0, "inventory":0}]}'
        end
    end
end
