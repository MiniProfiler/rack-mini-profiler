require "benchmark"
require "ruby-debug"
module Rack

	class PageTimingStruct

	end
	class TimingStruct
		attr_accessor :id, :name, :started, :machineName, :level, :root, :user, :hasUserViewed
		attr_accessor :clientTimings, :durationMilliseconds, :hasTrivialTimings
		attr_accessor :trivialDurationThresholdMilliseconds, :head, :durationMillisecondsInSql
		attr_accessor :hasSqlTimings, :hasDuplicateSqlTimings
		attr_accessor :executedReaders, :executedScalars, :executedNonQueries

		def self.clean_defaults(env)
			{
				:name => env['PATH_INFO'],
				:started => (Time.now.to_f * 1000).to_i, # time in ms
				:machineName => env['SERVER_NAME'],
			}
		end
		def self.create_root(env)
			self.new(env, {
				:root => true,
				:level => 0,
				}.merge(self.clean_defaults(env)))
		end
		def generate_id
			rand(36**20).to_s(36)
		end

		def initialize(env, attributes)
			defaults = { :id => generate_id }
			@attributes = defaults.merge(attributes)
		end
	end

	class MiniProfiler

		VERSION = 'rZlycOOTnzxZvxTmFuOEV0dSmu4P5m5bLrCtwJHVXPA='.freeze

		# DONE todo send all css files from StackExchange.Profiling.UI
		# DONE need the "should I profile" option
		# DONE Prefix needs to be configured
		# DONE set long expiration header on files you server
		# at the end of the page, send a stub from MiniProfileHandler.cs
		# Set X-MiniProfilerID header, cache the results
		# Get json format from http://data.stackexchange.com/ last xhr request
		# override log_duration for sequel
		def initialize(app, options={})
			@options = {
				:auto_inject => true,	# automatically inject on every html page
				:auto_libs => true, # append body with libraries automatically
				:serve_libs => true, # what libraries to server automatically
				:base_url_path => "/mini-profiler-resources",
				:authorize_cb => lambda {|env| return true;} # callback returns true if this request is authorized to profile
			}.merge(options)
			@app = app
			@options[:base_url_path] += "/" unless @options[:base_url_path].end_with? "/"
		end

		def serve_html(env)
			file_name = env['PATH_INFO'][(@options[:base_url_path].length)..1000]
			full_path = ::File.expand_path("../html/#{file_name}", ::File.dirname(__FILE__))
			return [404, {}, ["Not found"]] unless ::File.exists? full_path
			f = Rack::File.new nil
			f.path = full_path
			f.cache_control = "max-age:86400"
			f.serving env
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
			tms = Benchmark.measure do
				status, headers, body = @app.call(env)
			end

			# script injection
			if @inject_js \
				&& status == 200 \
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

			[status, headers, body]
		end

		def get_js_script
			ids = [].join #TODO ids: ["fbfb4a45-722f-4c72-be17-197cc61f9af4","e45dffcb-f62b-4859-a9a4-23f53ccd0587"],
			path = @options[:base_url_path]
			version = MiniProfiler::VERSION
			position = 'left'
			showTrivial = true
			showChildrenTime = true
			maxTracesToShow = 15
			showControls = true
			currentId = # TODO 'e45dffcb-f62b-4859-a9a4-23f53ccd0587',
			authorized = true
			script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
			[:ids, :path, :version, :position, :showTrivial, :showChildrenTime, :maxTracesToShow, :showControls, :currentId, :authorized].each do |v|
				regex = Regexp.new("\\{#{v.to_s}\\}")
				puts v
				script.gsub!(regex, eval(v.to_s).to_s)
			end
			@inject_js = false
			script
		end

		def step
			# profile given block
		end
	end

end

