require './app'

use Rack::ShowExceptions

use Rack::Static, :urls => {"/" => 'index.html'}, :root => 'public'
use Rack::Static, :urls => ["/static"], :root => "public"

run App.new
