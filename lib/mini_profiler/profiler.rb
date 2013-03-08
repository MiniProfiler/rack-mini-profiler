require 'json'
require 'timeout'
require 'thread'

require 'mini_profiler/version'
require 'mini_profiler/page_timer_struct'
require 'mini_profiler/sql_timer_struct'
require 'mini_profiler/custom_timer_struct'
require 'mini_profiler/client_timer_struct'
require 'mini_profiler/request_timer_struct'
require 'mini_profiler/storage/abstract_store'
require 'mini_profiler/storage/memcache_store'
require 'mini_profiler/storage/memory_store'
require 'mini_profiler/storage/redis_store'
require 'mini_profiler/storage/file_store'
require 'mini_profiler/config'
require 'mini_profiler/profiling_methods'
require 'mini_profiler/context'
require 'mini_profiler/client_settings'
require 'mini_profiler/gc_profiler'

module Rack

  class MiniProfiler

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

      # Add a custom timing. These are displayed similar to SQL/query time in
      # columns expanding to the right.
      #
      # type        - String counter type. Each distinct type gets its own column.
      # duration_ms - Duration of the call in ms. Either this or a block must be
      #               given but not both.
      #
      # When a block is given, calculate the duration by yielding to the block
      # and keeping a record of its run time.
      #
      # Returns the result of the block, or nil when no block is given.
      def counter(type, duration_ms=nil)
        result = nil
        if block_given?
          start = Time.now
          result = yield
          duration_ms = (Time.now - start).to_f * 1000
        end
        return result if current.nil? || !request_authorized?
        current.current_timer.add_custom(type, duration_ms, current.page_struct)
        result
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
        html.gsub!(/\{duration\}/, "%.1f" % page_struct.duration_ms)

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
      else
        client_settings.disable_profiling = false
      end

      if query_string =~ /pp=profile-gc/
        # begin
          if query_string =~ /pp=profile-gc-time/
            return Rack::MiniProfiler::GCProfiler.new.profile_gc_time(@app, env)
          else
            return Rack::MiniProfiler::GCProfiler.new.profile_gc(@app, env)
          end
        # rescue => e
        #   p e
        #   e.backtrace.each do |s|
        #     puts s
        #   end
        # end
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
      stacktrace_installed = true
      if query_string =~ /pp=sample/
        skip_frames = 0
        backtraces = []
        t = Thread.current

        begin
          require 'stacktrace'
          skip_frames = stacktrace.length
        rescue LoadError
          stacktrace_installed = false
        end

        Thread.new {
          begin
            i = 10000 # for sanity never grab more than 10k samples
            while i > 0
              break if done_sampling
              i -= 1
              if stacktrace_installed
                backtraces << t.stacktrace(0,-(1+skip_frames), StackFrame::Flags::METHOD | StackFrame::Flags::KLASS)
              else
                backtraces << t.backtrace
              end
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
        # this is non-obvious, don't kill the profiling cookie on errors or short requests
        # this ensures that stuff that never reaches the rails stack does not kill profiling
        if status == 200 && ((Time.now - start) > 0.1)
          client_settings.discard_cookie!(headers)
        end
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
        return help(client_settings)
      end

      page_struct = current.page_struct
      page_struct['User'] = user(env)
      page_struct['Root'].record_time((Time.now - start) * 1000)

      if backtraces
        body.close if body.respond_to? :close
        return analyze(backtraces, page_struct)
      end


      # no matter what it is, it should be unviewed, otherwise we will miss POST
      @storage.set_unviewed(page_struct['User'], page_struct['Id'])
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
      if fragment.match(/<\/body>/i)
        # explicit </body>

        regex = /<\/body>/i
        close_tag = '</body>'
      elsif fragment.match(/<\/html>/i)
        # implicit </body>

        regex = /<\/html>/i
        close_tag = '</html>'
      else
        # implicit </body> and </html>. Just append the script.

        return fragment + script
      end

      fragment.sub(regex) do
        # if for whatever crazy reason we dont get a utf string,
        #   just force the encoding, no utf in the mp scripts anyway
        if script.respond_to?(:encoding) && script.respond_to?(:force_encoding)
          (script + close_tag).force_encoding(fragment.encoding)
        else
          script + close_tag
        end
      end
    end

    def dump_env(env)
      headers = {'Content-Type' => 'text/plain'}
      body = "Rack Environment\n---------------\n"
      env.each do |k,v|
        body << "#{k}: #{v}\n"
      end

      body << "\n\nEnvironment\n---------------\n"
      ENV.each do |k,v|
        body << "#{k}: #{v}\n"
      end


      [200, headers, [body]]
    end

    def help(client_settings)
      headers = {'Content-Type' => 'text/plain'}
      body = "Append the following to your query string:

  pp=help : display this screen
  pp=env : display the rack environment
  pp=skip : skip mini profiler for this request
  pp=no-backtrace #{"(*) " if client_settings.backtrace_none?}: don't collect stack traces from all the SQL executed (sticky, use pp=normal-backtrace to enable)
  pp=normal-backtrace #{"(*) " if client_settings.backtrace_default?}: collect stack traces from all the SQL executed and filter normally
  pp=full-backtrace #{"(*) " if client_settings.backtrace_full?}: enable full backtraces for SQL executed (use pp=normal-backtrace to disable)
  pp=sample : sample stack traces and return a report isolating heavy usage (experimental works best with the stacktrace gem)
  pp=disable : disable profiling for this session
  pp=enable : enable profiling for this session (if previously disabled)
  pp=profile-gc: perform gc profiling on this request, analyzes ObjectSpace generated by request (ruby 1.9.3 only)
  pp=profile-gc-time: perform built-in gc profiling on this request (ruby 1.9.3 only)
"

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
          frame = "#{frame.klass}::#{frame.method}" unless String === frame
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

    def ids_comma_separated(env)
      # cap at 10 ids, otherwise there is a chance you can blow the header
      ids = [current.page_struct["Id"]] + (@storage.get_unviewed_ids(user(env)) || [])[0..8]
      ids.join(",")
    end

    # get_profile_script returns script to be injected inside current html page
    # By default, profile_script is appended to the end of all html requests automatically.
    # Calling get_profile_script cancels automatic append for the current page
    # Use it when:
    # * you have disabled auto append behaviour throught :auto_inject => false flag
    # * you do not want script to be automatically appended for the current page. You can also call cancel_auto_inject
    def get_profile_script(env)
      ids = ids_comma_separated(env)
      path = @config.base_url_path
      version = MiniProfiler::VERSION
      position = @config.position
      showTrivial = false
      showChildren = false
      maxTracesToShow = 10
      showControls = false
      currentId = current.page_struct["Id"]
      authorized = true
      # TODO : cache this snippet
      script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
      # replace the variables
      [:ids, :path, :version, :position, :showTrivial, :showChildren, :maxTracesToShow, :showControls, :currentId, :authorized].each do |v|
        regex = Regexp.new("\\{#{v.to_s}\\}")
        script.gsub!(regex, eval(v.to_s).to_s)
      end
      current.inject_js = false
      script
    end

    # cancels automatic injection of profile script for the current page
    def cancel_auto_inject(env)
      current.inject_js = false
    end

  end

end

