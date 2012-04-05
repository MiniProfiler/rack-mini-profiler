#! rackup -
#\ -w -p 8080 
require 'active_support/inflector' # see https://code.google.com/p/ruby-sequel/issues/detail?id=329
require 'sequel'
require File.expand_path('../lib/rack-mini-profiler', File.dirname(__FILE__))

require 'logger'
use Rack::MiniProfiler
options = {}
options[:logger] = Logger.new(STDOUT)
DB = Sequel.connect("mysql2://sveg:svegsveg@localhost/sveg_development",
	options)

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
				DB.fetch('SHOW TABLES') do |row|
					puts row
				end
			end
			env['profiler.mini'].benchmark('litl sql') do
				DB.fetch('select * from auth_logins') do |row|
					puts row
				end
			end
		end
	end
  [ 200, {'Content-Type' => 'text/html'}, ["<h1>This is Rack::MiniProfiler test"] ]
end

puts "Rack::MiniProfiler test"
puts "http://localhost:8080/mini-profiler"
run app
