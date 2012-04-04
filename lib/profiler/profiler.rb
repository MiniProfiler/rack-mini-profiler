require 'benchmark'
require 'json'

require "ruby-debug"

# DONE todo send all css files from StackExchange.Profiling.UI
# DONE need the "should I profile" option
# DONE Prefix needs to be configured
# DONE set long expiration header on files you server
# DONE at the end of the page, send a stub from MiniProfileHandler.cs
# Set X-MiniProfilerID header, cache the results
# Get json format from http://data.stackexchange.com/ last xhr request
# override log_duration for sequel
# cache cleanup

module Rack

	class MiniProfiler

		VERSION = 'rZlycOOTnzxZvxTmFuOEV0dSmu4P5m5bLrCtwJHVXPA='.freeze

		def self.instance
			@@instance
		end

		def self.generate_id
			rand(36**20).to_s(36)
		end

		# Structs holding Page loading data
		# PageStruct
		#   ClientTimings: ClientTimingsStruct
		#   Root: RequestTimings
		#     :has_many RequestTimings children
		#     :has_many SqlTimings children
		class ClientTimingsStruct
			def initialize(env)
				@attributes = {}
			end

			def to_json(*a)
				@attributes.to_json(*a)
			end

			def init_from_form_data(env)				
				debugger
				timings = []
				formTime = env['rack.request.form_hash']['clientPerformance']['timing']
				timings.push({ "Name" => "Domain Lookup", 
					"Start" =>  formTime['domainLookupStart'].to_i, 
					"Duration" => formTime['domainLookupEnd'].to_i - formTime['domainLookupStart'].to_i
				})
				timings.push( { "Name" => "Connect", 
					"Start" =>  formTime['connectStart'].to_i, 
					"Duration" => formTime['connectEnd'].to_i - formTime['connectStart'].to_i
				})
				timings.push({ "Name" => "Request Start", 
					"Start" =>  formTime['requestStart'].to_i, 
					"Duration" => -1
				})
				timings.push( { "Name" => "Response", 
					"Start" =>  formTime['responseStart'].to_i, 
					"Duration" => formTime['responseEnd'].to_i - formTime['responseStart'].to_i
				})
				timings.push( { "Name" => "Unload Event", 
					"Start" =>  formTime['unloadEventStart'].to_i, 
					"Duration" => formTime['unloadEventEnd'].to_i - formTime['unloadEventStart'].to_i
				})
				timings.push( { "Name" => "Dom Loading", 
					"Start" =>  formTime['domLoading'].to_i, 
					"Duration" => -1
				})
				timings.push( { "Name" => "Dom Content Loaded Event", 
					"Start" =>  formTime['domContentLoadedEventStart'].to_i, 
					"Duration" => formTime['domContentLoadedEventEnd'].to_i - formTime['domContentLoadedEventStart'].to_i
				})
				timings.push( { "Name" => "Dom Interactive", 
					"Start" =>  formTime['domInteractive'].to_i, 
					"Duration" => -1
				})
				timings.push( { "Name" => "Load Event", 
					"Start" =>  formTime['loadEventStart'].to_i, 
					"Duration" => formTime['loadEventEnd'].to_i - formTime['loadEventStart'].to_i
				})
				timings.push( { "Name" => "Dom Complete", 
					"Start" =>  formTime['domComplete'].to_i, 
					"Duration" => -1
				})
				@attributes.merge!({
					"RedirectCount" => env['rack.request.form_hash']['clientPerformance']['navigation']['redirectCount'],
					"Timings" => timings
				})
			end
		end

		class RequestTimingsStruct
			def self.createRoot(env)
				rt = RequestTimingsStruct.new(env)
				rt["IsRoot"]= true
				rt
			end

			def initialize(env)
				@attributes = {
					"Id" => MiniProfiler.generate_id,
					"Name" => "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}",
					"DurationMilliseconds" => 0,
					"StartMilliseconds" => 0,
					"Children" => [],
					"KeyValues" => nil,
					"SqlTimings" => [],
					"ParentTimingId" => nil,
					"DurationWithoutChildrenMilliseconds"=> 0,
					"SqlTimingsDurationMilliseconds"=> 0,
					"IsTrivial"=> false,
					"HasChildren"=> true,
					"HasSqlTimings"=> true,
					"HasDuplicateSqlTimings"=> false,
					"IsRoot"=> true,
					"Depth"=> 0,
					"ExecutedReaders"=> 0,
					"ExecutedScalars"=> 0,
					"ExecutedNonQueries"=> 0				
				}
			end
			
			def []=(name, value)
				@attributes[name] = value
				self
			end

			def to_json(*a)
				@attributes.to_json(*a)
			end
		end

		# MiniProfiles page, part of 
		class PageStruct
			def initialize(env)
				@attributes = {
					"Id" => MiniProfiler.generate_id,
					"Name" => env['PATH_INFO'],
					"Started" => (Time.now.to_f * 1000).to_i,
					"MachineName" => env['SERVER_NAME'],
					"Level" => 0,
					"Root" => RequestTimingsStruct.createRoot(env),
					"User" => "unknown user",
					"HasUserViewed" => false,
					"ClientTimings" => ClientTimingsStruct.new(env),
					"DurationMilliseconds" => 0,
					"HasTrivialTimings" => true,
					"HasAllTrivialTimigs" => false,
					"TrivialDurationThresholdMilliseconds" => 2,
					"Head" => nil,
					"DurationMillisecondsInSql" => 4.9,
					"HasSqlTimings" => true,
					"HasDuplicateSqlTimings" => false,
					"ExecutedReaders" => 3,
					"ExecutedScalars" => 0,
					"ExecutedNonQueries" => 1
				}
			end

			def [](name)
				@attributes[name]
			end

			def []=(name, val)
				@attributes[name] = val
			end

			def to_json(*a)
				@attributes.to_json(*a)
			end
		end


		def initialize(app, options={})
			@@instance = self
			@options = {
				:auto_inject => true,	# automatically inject on every html page
				:auto_libs => true, # append body with libraries automatically
				:serve_libs => true, # what libraries to server automatically
				:base_url_path => "/mini-profiler-resources",
				:authorize_cb => lambda {|env| return true;} # callback returns true if this request is authorized to profile
			}.merge(options)
			@app = app
			@options[:base_url_path] += "/" unless @options[:base_url_path].end_with? "/"

			@timings_cache = {}
		end

		def serve_results(env)
			request = Rack::Request.new(env)
			page_struct = @timings_cache[request['id']]
			return [404, {} ["No such result #{request['id']}"]] unless page_struct
			unless page_struct['HasUserViewed']
				page_struct['ClientTimings'].init_from_form_data(env)
				page_struct["HasUserViewed"] = true
			end
			[200, { 'Content-Type' => 'application/json'}, [page_struct.to_json]]
		end

		def serve_html(env)
			file_name = env['PATH_INFO'][(@options[:base_url_path].length)..1000]
			return serve_results(env) if file_name.eql?('results')
			full_path = ::File.expand_path("../html/#{file_name}", ::File.dirname(__FILE__))
			return [404, {}, ["Not found"]] unless ::File.exists? full_path
			f = Rack::File.new nil
			f.path = full_path
			f.cache_control = "max-age:86400"
			f.serving env
		end

		def add_to_timings(page_struct)
			@timings_cache[page_struct['Id']] = page_struct
		end

		def call(env)
			status = headers = body = nil
			env['profiler.mini'] = self

			# only profile if authorized
			return @app.call(env) unless @options[:authorize_cb].call(env)

			# handle all /mini-profiler requests here
 			return serve_html(env) if env['PATH_INFO'].start_with? @options[:base_url_path]

 			@inject_js = @options[:auto_inject]
 			# profiling the request

 			@page_struct = PageStruct.new(env)
 			@current_timing = @page_struct["Root"]
			tms = Benchmark.measure do
				status, headers, body = @app.call(env)
			end

			if status == 200
				add_to_timings(@page_struct)
				# inject header
				headers['X-MiniProfilerID'] = @page_struct["Id"] if headers.is_a? Hash
				# inject script
				if @inject_js \
					&& headers.has_key?('Content-Type') \
					&& !headers['Content-Type'].match(/text\/html/).nil? then
					if (body.respond_to? :push)
						body.push(self.get_js_script)
					elsif (body.is_a? String)
						body += self.get_js_script
					else
						env['rack.logger'].error('could not attach mini-profiler to body, can only attach to Arrays and Strings')
					end
				end
			end

			[status, headers, body]
		end

		def get_js_script
			ids = [@page_struct["Id"]].to_s
			path = @options[:base_url_path]
			version = MiniProfiler::VERSION
			position = 'left'
			showTrivial = true
			showChildren = true
			maxTracesToShow = 15
			showControls = true
			currentId = @page_struct["Id"]
			authorized = true
			script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
			[:ids, :path, :version, :position, :showTrivial, :showChildren, :maxTracesToShow, :showControls, :currentId, :authorized].each do |v|
				regex = Regexp.new("\\{#{v.to_s}\\}")
				script.gsub!(regex, eval(v.to_s).to_s)
			end
			script.gsub!(/{{/, '{').gsub!(/}}/, '}')
			@inject_js = false
			script
		end

		def step
			# profile given block
		end
	end

end

