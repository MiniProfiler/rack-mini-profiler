#! rackup -
#\ -w -p 8080 
require File.expand_path('../lib/rack-mini-profiler', File.dirname(__FILE__))

use Rack::MiniProfiler

app = proc do |env|
	sleep(0.1)
	env['profiler.mini'].benchmark("sleep0.2") do
		sleep(0.2)
	end
	env['profiler.mini'].benchmark('sleep0.1') do
		sleep(0.1)
		env['profiler.mini'].benchmark('sleep0.01') do
			sleep(0.01)
			env['profiler.mini'].benchmark('sleep0.001') do
				sleep(0.001)
			end
		end
	end
  [ 200, {'Content-Type' => 'text/html'}, ["<h1>This is Rack::MiniProfiler test"] ]
end

puts "Rack::MiniProfiler test"
puts "http://localhost:8080/mini-profiler"
run app
