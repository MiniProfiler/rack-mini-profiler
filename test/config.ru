#! rackup -
#\ -w -p 8080 
require File.expand_path('../lib/rack-mini-profiler', File.dirname(__FILE__))

use Rack::MiniProfiler

app = proc do |env|
  [ 200, {'Content-Type' => 'text/html'}, ["<h1>This is Rack::MiniProfiler test"] ]
end

puts "Rack::MiniProfiler test"
puts "http://localhost:8080/mini-profiler"
run app
