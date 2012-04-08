# rake test:all TEST=test/basic.rb

require 'test/unit'
require 'active_record'
require 'rack/test'

require './lib/rack-mini-profiler'
class BasicTest < Test::Unit::TestCase
	include Rack::Test::Methods

	def app
		unless defined? @app
			builder = Rack::Builder.new {
				use Rack::MiniProfiler
				map '/html' do
					run lambda { |env| sleep 0.5; [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1'] }
				end
			}
			@app = builder.to_app
		end
		@app 
	end

	def test_html_time
		get '/html'
		assert last_response.status == 200
	end
end
