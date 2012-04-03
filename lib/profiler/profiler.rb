require "benchmark"
require "ruby-debug"
module Rack

	class MiniProfiler

		# DONE todo send all css files from StackExchange.Profiling.UI
		# DONE need the "should I profile" option
		# DONE Prefix needs to be configured
		# DONE set long expiration header on files you server
		# at the end of the page, send a stub from MiniProfileHandler.cs
		# Set X-MiniProfilerID header, cache the results
		# Get json format from http://data.stackexchange.com/ last xhr request
		def initialize(app, options={})
			@options = {
				:auto => true,	# automatically load on every html page
				:auto_libs => true, # append body with libraries automatically
				:serve_libs => true, # what libraries to server automatically
				:base_url_path => "/mini-profiler",
				:authorize_cb => lambda {|env| return true;} # callback returns true if this request is authorized to profile
			}.merge(options)
			@app = app
			@base_url_path = @options[:base_url_path]
			@base_url_path += "/" unless @base_url_path.end_with? "/"
		end

		def serve_html(env)
			file_name = env['REQUEST_PATH'][(@base_url_path.length)..1000]
			full_path = ::File.expand_path("../html/#{file_name}", ::File.dirname(__FILE__))
			return [404, {}, ["Not found"]] unless ::File.exists? full_path
			f = Rack::File.new nil
			f.path = full_path
			f.cache_control = "max-age:86400"
			f.serving env
		end

		def call(env)
			status = headers = body = nil
			env['x-mini_profiler'] = self

			# only profile if authorized
			return @app.call(env) unless @options[:authorize_cb].call(env)

			# handle all /mini-profiler requests here
 			return serve_html(env) if env['REQUEST_PATH'].start_with? @base_url_path

 			# profiling the request
			tms = Benchmark.measure do
				status, headers, body = @app.call(env)
			end
			# append results to body
			[status, headers, body]
		end

		def step
			# profile given block
		end
	end

end

