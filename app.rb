require 'rack'

class App
  def call(env)
    request = Rack::Request.new env
    response = Rack::Response.new

    case request.path
    when "/get-updates"
        response.write "get-updates"
    when "/create-change"
        response.write "create-change"
    end

    response.status = 200

    response.finish
  end

  
end
