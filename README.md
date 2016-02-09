# example-ruby-price-updates

Requirements:
* bolt 1.0a (with config.json from this repo)
* sqlite3 libs
* ruby 2.x+ w/ gems: bunny, json, sqlite3, base64, openssl, json, rack
* rabbitmq server with default config
* nginx configured to run with passenger / ruby

Run the bolt engine, and rabbitmq, then also run:
    ruby worker.rb

And:
    cd /opt/nginx/html && 
    passenger start

