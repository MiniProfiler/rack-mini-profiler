require 'json'
require 'timeout'
require 'thread'

require 'mini_profiler/page_timer_struct'
require 'mini_profiler/sql_timer_struct'
require 'mini_profiler/client_timer_struct'
require 'mini_profiler/request_timer_struct'
require 'mini_profiler/storage/abstract_store'
require 'mini_profiler/storage/memory_store'
require 'mini_profiler/storage/redis_store'
require 'mini_profiler/storage/file_store'
require 'mini_profiler/config'
require 'mini_profiler/profiling_methods'
require 'mini_profiler/context'
require 'mini_profiler/client_settings'

module Rack

	class MiniProfiler

		VERSION = '106'.freeze

    class << self 
      
      include Rack::MiniProfiler::ProfilingMethods

      def generate_id
        rand(36**20).to_s(36)
      end

      def reset_config
        @config = Config.default
      end

      # So we can change the configuration if we want
      def config
        @config ||= Config.default
      end

      def share_template
        return @share_template unless @share_template.nil?
        @share_template = ::File.read(::File.expand_path("../html/share.html", ::File.dirname(__FILE__)))
      end
      
      def current
        Thread.current[:mini_profiler_private]
      end

      def current=(c)
        # we use TLS cause we need access to this from sql blocks and code blocks that have no access to env
        Thread.current[:mini_profiler_private]= c
      end

      # discard existing results, don't track this request
      def discard_results
        self.current.discard = true if current
      end

      def create_current(env={}, options={})
        # profiling the request
        self.current = Context.new
        self.current.inject_js = config.auto_inject && (!env['HTTP_X_REQUESTED_WITH'].eql? 'XMLHttpRequest')
        self.current.page_struct = PageTimerStruct.new(env)
        self.current.current_timer = current.page_struct['Root']
      end

      def authorize_request
        Thread.current[:mp_authorized] = true
      end

      def deauthorize_request
        Thread.current[:mp_authorized] = nil
      end

      def request_authorized?
        Thread.current[:mp_authorized]
      end
    end

		#
		# options:
		# :auto_inject - should script be automatically injected on every html page (not xhr)
		def initialize(app, config = nil)
      MiniProfiler.config.merge!(config)
      @config = MiniProfiler.config 
			@app = app
			@config.base_url_path << "/" unless @config.base_url_path.end_with? "/"
      unless @config.storage_instance
        @config.storage_instance = @config.storage.new(@config.storage_options)
      end
      @storage = @config.storage_instance 
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
        page_struct['ClientTimings'] = ClientTimerStruct.init_from_form_data(env, page_struct)
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

      begin 
        f.cache_control = "max-age:86400"
        f.serving env
      rescue
        # old versions of rack have a different api 
        status, headers, body = f.serving
        headers.merge! 'Cache-Control' => "max-age:86400"
        [status, headers, body]
      end

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


		def call(env)
      client_settings = ClientSettings.new(env)

      status = headers = body = nil
      query_string = env['QUERY_STRING']
      path = env['PATH_INFO']

      skip_it = (@config.pre_authorize_cb && !@config.pre_authorize_cb.call(env)) ||
                (@config.skip_paths && @config.skip_paths.any?{ |p| path[0,p.length] == p}) ||
                query_string =~ /pp=skip/ 
      
      has_profiling_cookie = client_settings.has_cookie?
    
      if skip_it || (@config.authorization_mode == :whitelist && !has_profiling_cookie)
        status,headers,body = @app.call(env)
        if !skip_it && @config.authorization_mode == :whitelist && !has_profiling_cookie && MiniProfiler.request_authorized? 
          client_settings.write!(headers) 
        end
        return [status,headers,body]
      end

      # handle all /mini-profiler requests here
			return serve_html(env) if path.start_with? @config.base_url_path

      has_disable_cookie = client_settings.disable_profiling?
      # manual session disable / enable
      if query_string =~ /pp=disable/ || has_disable_cookie
        skip_it = true
      end

      if query_string =~ /pp=enable/
        skip_it = false
      end

      if skip_it
        status,headers,body = @app.call(env)
        client_settings.disable_profiling = true
        client_settings.write!(headers)
        return [status,headers,body]
      end

      MiniProfiler.create_current(env, @config)
      MiniProfiler.deauthorize_request if @config.authorization_mode == :whitelist
      if query_string =~ /pp=normal-backtrace/
        client_settings.backtrace_level = ClientSettings::BACKTRACE_DEFAULT
      elsif query_string =~ /pp=no-backtrace/
        current.skip_backtrace = true
        client_settings.backtrace_level = ClientSettings::BACKTRACE_NONE
      elsif query_string =~ /pp=full-backtrace/ || client_settings.backtrace_full?
        current.full_backtrace = true
        client_settings.backtrace_level = ClientSettings::BACKTRACE_FULL
      elsif client_settings.backtrace_none?
        current.skip_backtrace = true
      end

      done_sampling = false
      quit_sampler = false
      backtraces = nil
      missing_stacktrace = false
      if query_string =~ /pp=sample/
        backtraces = []
        t = Thread.current
        Thread.new {
          begin
            i = 10000 # for sanity never grab more than 10k samples 
            while i > 0
              break if done_sampling
              i -= 1
              backtraces << t.backtrace
              sleep 0.001
            end
          ensure
            quit_sampler = true
          end
        }
      end

			status, headers, body = nil
      start = Time.now 
      begin 

        # Strip all the caching headers so we don't get 304s back 
        #  This solves a very annoying bug where rack mini profiler never shows up
        env['HTTP_IF_MODIFIED_SINCE'] = nil
        env['HTTP_IF_NONE_MATCH'] = nil

        status,headers,body = @app.call(env)
        client_settings.write!(headers)
      ensure
        if backtraces 
          done_sampling = true
          sleep 0.001 until quit_sampler
        end
      end

      skip_it = current.discard
      if (config.authorization_mode == :whitelist && !MiniProfiler.request_authorized?)
        client_settings.discard_cookie!(headers)
        skip_it = true
      end
      
      return [status,headers,body] if skip_it

      # we must do this here, otherwise current[:discard] is not being properly treated
      if query_string =~ /pp=env/
        body.close if body.respond_to? :close
        return dump_env env
      end

      if query_string =~ /pp=help/
        body.close if body.respond_to? :close
        return help(nil, client_settings)
      end
      
      page_struct = current.page_struct
			page_struct['Root'].record_time((Time.now - start) * 1000)

      if backtraces
        body.close if body.respond_to? :close
        return help(:stacktrace, client_settings) if missing_stacktrace
        return analyze(backtraces, page_struct)
      end
      

      # no matter what it is, it should be unviewed, otherwise we will miss POST
      @storage.set_unviewed(user(env), page_struct['Id']) 
			@storage.save(page_struct)
			
      # inject headers, script
			if status == 200

        client_settings.write!(headers)
        
        # mini profiler is meddling with stuff, we can not cache cause we will get incorrect data
        # Rack::ETag has already inserted some nonesense in the chain
        headers.delete('ETag')
        headers.delete('Date')
        headers['Cache-Control'] = 'must-revalidate, private, max-age=0'

				# inject header
        if headers.is_a? Hash
          headers['X-MiniProfiler-Ids'] = ids_json(env)
        end

				# inject script
				if current.inject_js \
					&& headers.has_key?('Content-Type') \
					&& !headers['Content-Type'].match(/text\/html/).nil? then
					
          response = Rack::Response.new([], status, headers)
          script = self.get_profile_script(env)
          if String === body
            response.write inject(body,script)
          else
            body.each { |fragment| response.write inject(fragment, script) }
          end
          body.close if body.respond_to? :close
          return response.finish
				end
			end

      client_settings.write!(headers)
			[status, headers, body]
    ensure
      # Make sure this always happens
      current = nil
		end

    def inject(fragment, script)
      fragment.sub(/<\/body>/i) do 
        # if for whatever crazy reason we dont get a utf string, 
        #   just force the encoding, no utf in the mp scripts anyway 
        if script.respond_to?(:encoding) && script.respond_to?(:force_encoding)
          (script + "</body>").force_encoding(fragment.encoding)
        else
          script + "</body>"
        end
      end
    end

    def dump_env(env)
      headers = {'Content-Type' => 'text/plain'}
      body = "" 
      env.each do |k,v|
        body << "#{k}: #{v}\n"
      end
      [200, headers, [body]]
    end

    def help(category = nil, client_settings)
      headers = {'Content-Type' => 'text/plain'}
      body = "Append the following to your query string:

  pp=help : display this screen
  pp=env : display the rack environment
  pp=skip : skip mini profiler for this request
  pp=no-backtrace #{"(*) " if client_settings.backtrace_none?}: don't collect stack traces from all the SQL executed (sticky, use pp=normal-backtrace to enable)
  pp=normal-backtrace #{"(*) " if client_settings.backtrace_default?}: collect stack traces from all the SQL executed and filter normally
  pp=full-backtrace #{"(*) " if client_settings.backtrace_full?}: enable full backtraces for SQL executed (use pp=normal-backtrace to disable) 
  pp=sample : sample stack traces and return a report isolating heavy usage (experimental)
  pp=disable : disable profiling for this session 
  pp=enable : enable profiling for this session (if previously disabled)
"
      if (category == :stacktrace)
        body = "pp=stacktrace requires the stacktrace gem - add gem 'stacktrace' to your Gemfile"
      end
    
      client_settings.write!(headers)
      [200, headers, [body]]
    end

    def analyze(traces, page_struct)
      headers = {'Content-Type' => 'text/plain'}
      body = "Collected: #{traces.count} stack traces. Duration(ms): #{page_struct.duration_ms}"

      seen = {}
      fulldump = ""
      traces.each do |trace| 
        fulldump << "\n\n"
        distinct = {}
        trace.each do |frame|
          unless distinct[frame]
            distinct[frame] = true
            seen[frame] ||= 0
            seen[frame] += 1
          end
          fulldump << frame << "\n"
        end
      end

      body << "\n\nStack Trace Analysis\n"
      seen.to_a.sort{|x,y| y[1] <=> x[1]}.each do |name, count|
        if count > traces.count / 10
          body << "#{name} x #{count}\n"
        end
      end
      
      body << "\n\n\nRaw traces \n"
      body << fulldump

      [200, headers, [body]]
    end

    def ids_json(env)
      # cap at 10 ids, otherwise there is a chance you can blow the header
      ids = [current.page_struct["Id"]] + (@storage.get_unviewed_ids(user(env)) || [])[0..8]
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
			currentId = current.page_struct["Id"]
			authorized = true
			useExistingjQuery = @config.use_existing_jquery
			# TODO : cache this snippet 
			script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
			# replace the variables
			[:ids, :path, :version, :position, :showTrivial, :showChildren, :maxTracesToShow, :showControls, :currentId, :authorized, :useExistingjQuery].each do |v|
				regex = Regexp.new("\\{#{v.to_s}\\}")
				script.gsub!(regex, eval(v.to_s).to_s)
			end
			# replace the '{{' and '}}''
			script.gsub!(/\{\{/, '{').gsub!(/\}\}/, '}')
			current.inject_js = false
			script
		end

		# cancels automatic injection of profile script for the current page
		def cancel_auto_inject(env)
		  current.inject_js = false
		end

	end

end

