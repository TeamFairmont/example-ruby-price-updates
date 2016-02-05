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
        key = 'another_hmac_key'
        group = 'enduser'
        resp = '{"since":1999999}'
        data={}
        data['timestamp']=Time.now.to_i.to_s
        data['message']=resp
        digest = OpenSSL::Digest.new('sha512')

        hmacsig = Base64.encode64(OpenSSL::HMAC.hexdigest(digest, key, JSON.generate(data)))
        resp64 = Base64.encode64(JSON.generate(data))
        pdata={}
        pdata['signature']=hmacsig
        pdata['data']=resp64

        uri = URI.parse("http://localhost:8888/request/products/get-updated")

        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.basic_auth(group, "password_ignored")
        request.body=JSON.generate(pdata)
        engineres = http.request(request)

        response.write JSON.generate(JSON.parse(engineres.body)['return_value'])
    end

    response.status = 200

    response.finish
  end


end
