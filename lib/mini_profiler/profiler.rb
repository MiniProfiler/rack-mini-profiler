require 'json'
require 'timeout'
require 'thread'

require 'mini_profiler/page_timer_struct'
require 'mini_profiler/sql_timer_struct'
require 'mini_profiler/client_timer_struct'
require 'mini_profiler/request_timer_struct'
require 'mini_profiler/body_add_proxy'
require 'mini_profiler/storage/abstract_store'
require 'mini_profiler/storage/memory_store'
require 'mini_profiler/storage/redis_store'
require 'mini_profiler/storage/file_store'
require 'mini_profiler/config'

module Rack

	class MiniProfiler

		VERSION = 'rZlycOOTnzxZvxTmFuOEV0dSmu4P5m5bLrCtwJHVXPA='.freeze
		@@instance = nil

		def self.instance
			@@instance
		end

		def self.generate_id
			rand(36**20).to_s(36)
		end

    def self.reset_config
      @config = Config.default
    end

    # So we can change the configuration if we want
    def self.config
      @config ||= Config.default
    end

    def self.share_template
      return @share_template unless @share_template.nil?
      @share_template = ::File.read(::File.expand_path("../html/share.html", ::File.dirname(__FILE__)))
    end

		#
		# options:
		# :auto_inject - should script be automatically injected on every html page (not xhr)
		def initialize(app, config = nil)
			@@instance = self
      MiniProfiler.config.merge!(config)
      @config = MiniProfiler.config 
			@app = app
			@config.base_url_path << "/" unless @config.base_url_path.end_with? "/"
      unless @config.storage_instance
        @storage = @config.storage_instance = @config.storage.new(@config.storage_options)
      end
		end
    
    def user(env)
      @config.user_provider.call(env)
    end

		def serve_results(env)
			request = Rack::Request.new(env)      
      id = request['id']
			page_struct = @storage.load(id)
      unless page_struct
        @storage.set_viewed(user(env), id) 
        return [404, {}, ["Request not found: #{request['id']} - user #{user(env)}"]] 
      end
			unless page_struct['HasUserViewed']
				page_struct['ClientTimings'].init_from_form_data(env, page_struct)
				page_struct['HasUserViewed'] = true
        @storage.save(page_struct) 
        @storage.set_viewed(user(env), id) 
			end

      result_json = page_struct.to_json
      # If we're an XMLHttpRequest, serve up the contents as JSON
      if request.xhr?
  			[200, { 'Content-Type' => 'application/json'}, [result_json]]
      else

        # Otherwise give the HTML back
        html = MiniProfiler.share_template.dup  
        html.gsub!(/\{path\}/, @config.base_url_path)      
        html.gsub!(/\{version\}/, MiniProfiler::VERSION)      
        html.gsub!(/\{json\}/, result_json)
        html.gsub!(/\{includes\}/, get_profile_script(env))
        html.gsub!(/\{name\}/, page_struct['Name'])
        html.gsub!(/\{duration\}/, page_struct.duration_ms.round(1).to_s)
        
        [200, {'Content-Type' => 'text/html'}, [html]]
      end

		end

		def serve_html(env)
			file_name = env['PATH_INFO'][(@config.base_url_path.length)..1000]
			return serve_results(env) if file_name.eql?('results')
			full_path = ::File.expand_path("../html/#{file_name}", ::File.dirname(__FILE__))
			return [404, {}, ["Not found"]] unless ::File.exists? full_path
			f = Rack::File.new nil
			f.path = full_path
			f.cache_control = "max-age:86400"
			f.serving env
		end

    def self.current
      Thread.current['profiler.mini.private']
    end

    def self.current=(c)
      # we use TLS cause we need access to this from sql blocks and code blocks that have no access to env
 			Thread.current['profiler.mini.private'] = c
    end

    def self.discard_results
      current[:discard] = true if current
    end
 
    def self.has_profiling_cookie?(env)
      env['HTTP_COOKIE'] && env['HTTP_COOKIE'].include?("__profilin=stylin")
    end

    def self.remove_profiling_cookie(headers)
      Rack::Utils.delete_cookie_header!(headers, '__profilin')
    end

    def self.set_profiling_cookie(headers)
      Rack::Utils.set_cookie_header!(headers, '__profilin', 'stylin')
    end

    def current
      MiniProfiler.current
    end

    def current=(c)
      MiniProfiler.current=c
    end

    def config
      @config
    end

    def self.create_current(env={}, options={})
      # profiling the request
      self.current = {}
      self.current['inject_js'] = config.auto_inject && (!env['HTTP_X_REQUESTED_WITH'].eql? 'XMLHttpRequest')
      self.current['page_struct'] = PageTimerStruct.new(env)
      self.current['current_timer'] = current['page_struct']['Root']
    end


		def call(env)
			status = headers = body = nil

      path = env['PATH_INFO']
			# only profile if authorized
			if  !@config.pre_authorize_cb.call(env) ||
          (@config.skip_paths && @config.skip_paths.any?{ |p| path[0,p.length] == p}) ||
          env["QUERY_STRING"] =~ /pp=skip/

        status,headers,body = @app.call(env)
        if @config.post_authorize_cb 
          if @config.post_authorize_cb.call(env) 
            self.class.set_profiling_cookie(headers)
          end
        end
        return [status,headers,body]
      end

      # handle all /mini-profiler requests here
			return serve_html(env) if env['PATH_INFO'].start_with? @config.base_url_path

      MiniProfiler.create_current(env, @config)
      if env["QUERY_STRING"] =~ /pp=no-backtrace/
        current['skip-backtrace'] = true
      end
      
      done_sampling = false
      quit_sampler = false
      backtraces = nil
      if env["QUERY_STRING"] =~ /pp=sample/
        backtraces = []
        t = Thread.current
        Thread.new {
          require 'stacktrace'
          if !t.respond_to? :stacktrace
            quit_sampler = true 
            return
          end
          i = 10000 # for sanity never grab more than 10k samples 
          while i > 0
            break if done_sampling
            i -= 1
            backtraces << t.stacktrace
            sleep 0.001
          end
          quit_sampler = true
        }
      end

			status, headers, body = nil
      start = Time.now 
      begin 
        status,headers,body = @app.call(env)
      ensure
        if backtraces 
          done_sampling = true
          sleep 0.001 until quit_sampler
        end
      end

      skip_it = current['discard']
      if @config.post_authorize_cb && !@config.post_authorize_cb.call(env)
        self.class.remove_profiling_cookie(headers)
        skip_it = true
      end

      return [status,headers,body] if skip_it
      
      # we must do this here, otherwise current['discard'] is not being properly treated
      if env["QUERY_STRING"] =~ /pp=env/
        body.close if body.respond_to? :close
        return dump_env env
      end

      if env["QUERY_STRING"] =~ /pp=help/
        body.close if body.respond_to? :close
        return help
      end
      
      page_struct = current['page_struct']
			page_struct['Root'].record_time((Time.now - start) * 1000)

      if backtraces
        body.close if body.respond_to? :close
        return analyze(backtraces, page_struct)
      end
      

      # no matter what it is, it should be unviewed, otherwise we will miss POST
      @storage.set_unviewed(user(env), page_struct['Id']) 
			@storage.save(page_struct)
			
      # inject headers, script
			if status == 200
        
				# inject header
        if headers.is_a? Hash
          headers['X-MiniProfiler-Ids'] = ids_json(env)
        end

				# inject script
				if current['inject_js'] \
					&& headers.has_key?('Content-Type') \
					&& !headers['Content-Type'].match(/text\/html/).nil? then
					body = MiniProfiler::BodyAddProxy.new(body, self.get_profile_script(env))
				end
			end

      # mini profiler is meddling with stuff, we can not cache cause we will get incorrect data
      # Rack::ETag has already inserted some nonesense in the chain
      headers.delete('ETag')
      headers.delete('Date')
      headers['Cache-Control'] = 'must-revalidate, private, max-age=0'
			[status, headers, body]
    ensure
      # Make sure this always happens
      current = nil
		end

    def dump_env(env)
      headers = {'Content-Type' => 'text/plain'}
      body = "" 
      env.each do |k,v|
        body << "#{k}: #{v}\n"
      end
      [200, headers, [body]]
    end

    def help
      headers = {'Content-Type' => 'text/plain'}
      body = "Append the following to your query string:

  pp=help : display this screen
  pp=env : display the rack environment
  pp=skip : skip mini profiler for this request
  pp=no-backtrace : don't collect stack traces from all the SQL calls
  pp=sample : sample stack traces and return a report isolating heavy usage (requires the stacktrace gem)
"
      #headers['Content-Length'] = body.length
      [200, headers, [body]]
    end

    def analyze(traces, page_struct)
      headers = {'Content-Type' => 'text/plain'}
      body = "Collected: #{traces.count} stack traces. Duration(ms): #{page_struct.duration_ms}"
      traces.each do |trace| 
        body << "\n\n"
        trace.each do |frame|
          body << "#{frame.klass} #{frame.method}\n"
        end
      end
      [200, headers, [body]]
    end

    def ids_json(env)
      ids = [current['page_struct']["Id"]] + (@storage.get_unviewed_ids(user(env)) || [])
      ::JSON.generate(ids.uniq)
    end

		# get_profile_script returns script to be injected inside current html page
		# By default, profile_script is appended to the end of all html requests automatically.
		# Calling get_profile_script cancels automatic append for the current page
		# Use it when:
		# * you have disabled auto append behaviour throught :auto_inject => false flag
		# * you do not want script to be automatically appended for the current page. You can also call cancel_auto_inject
		def get_profile_script(env)
			ids = ids_json(env)
			path = @config.base_url_path
			version = MiniProfiler::VERSION
			position = @config.position
			showTrivial = false
			showChildren = false
			maxTracesToShow = 10
			showControls = false
			currentId = current['page_struct']["Id"]
			authorized = true
      useExistingjQuery = false
			# TODO : cache this snippet 
			script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
			# replace the variables
			[:ids, :path, :version, :position, :showTrivial, :showChildren, :maxTracesToShow, :showControls, :currentId, :authorized, :useExistingjQuery].each do |v|
				regex = Regexp.new("\\{#{v.to_s}\\}")
				script.gsub!(regex, eval(v.to_s).to_s)
			end
			# replace the '{{' and '}}''
			script.gsub!(/\{\{/, '{').gsub!(/\}\}/, '}')
			current['inject_js'] = false
			script
		end

		# cancels automatic injection of profile script for the current page
		def cancel_auto_inject(env)
		  current['inject_js'] = false
		end

		# perform a profiling step on given block
		def self.step(name)
      if current
        old_timer = current['current_timer']
        new_step = RequestTimerStruct.new(name, current['page_struct'])
        current['current_timer'] = new_step
        new_step['Name'] = name
        start = Time.now
        result = yield if block_given?
        new_step.record_time((Time.now - start)*1000)
        old_timer.add_child(new_step)
        current['current_timer'] = old_timer
        result
      else
        yield if block_given?
      end
		end

    def self.profile_method(klass, method, &blk)
      default_name = klass.to_s + " " + method.to_s
      with_profiling = (method.to_s + "_with_mini_profiler").intern
      without_profiling = (method.to_s + "_without_mini_profiler").intern
      
      klass.send :alias_method, without_profiling, method
      klass.send :define_method, with_profiling do |*args, &orig|
        name = default_name 
        name = blk.bind(self).call(*args) if blk
        ::Rack::MiniProfiler.step name do 
          self.send without_profiling, *args, &orig
        end
      end
      klass.send :alias_method, method, with_profiling
    end

		def record_sql(query, elapsed_ms)
      c = current
			c['current_timer'].add_sql(query, elapsed_ms, c['page_struct'], c['skip-backtrace']) if (c && c['current_timer'])
		end

	end

end

