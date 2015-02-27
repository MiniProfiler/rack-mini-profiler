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
        @share_template ||= ::File.read(::File.expand_path("../html/share.html", ::File.dirname(__FILE__)))
      end

      def current
        Thread.current[:mini_profiler_private]
      end

      def current=(c)
        # we use TLS cause we need access to this from sql blocks and code blocks that have no access to env
        Thread.current[:mini_profiler_private] = c
      end

      # discard existing results, don't track this request
      def discard_results
        self.current.discard = true if current
      end

      def create_current(env={}, options={})
        # profiling the request
        self.current               = Context.new
        self.current.inject_js     = config.auto_inject && (!env['HTTP_X_REQUESTED_WITH'].eql? 'XMLHttpRequest')
        self.current.page_struct   = TimerStruct::Page.new(env)
        self.current.current_timer = current.page_struct[:root]
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
      @app    = app
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
      request     = Rack::Request.new(env)
      id          = request[:id]
      page_struct = @storage.load(id)
      unless page_struct
        @storage.set_viewed(user(env), id)
        id        = ERB::Util.html_escape(request['id'])
        user_info = ERB::Util.html_escape(user(env))
        return [404, {}, ["Request not found: #{id} - user #{user_info}"]]
      end
      unless page_struct[:has_user_viewed]
        page_struct[:client_timings]  = TimerStruct::Client.init_from_form_data(env, page_struct)
        page_struct[:has_user_viewed] = true
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
        html.gsub!(/\{path\}/, "#{env['SCRIPT_NAME']}#{@config.base_url_path}")
        html.gsub!(/\{version\}/, MiniProfiler::ASSET_VERSION)
        html.gsub!(/\{json\}/, result_json)
        html.gsub!(/\{includes\}/, get_profile_script(env))
        html.gsub!(/\{name\}/, page_struct[:name])
        html.gsub!(/\{duration\}/, "%.1f" % page_struct.duration_ms)

        [200, {'Content-Type' => 'text/html'}, [html]]
      end

    end

    def serve_html(env)
      file_name = env['PATH_INFO'][(@config.base_url_path.length)..1000]

      return serve_results(env) if file_name.eql?('results')

      full_path = ::File.expand_path("../html/#{file_name}", ::File.dirname(__FILE__))
      return [404, {}, ["Not found"]] unless ::File.exists? full_path
      f      = Rack::File.new nil
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
      MiniProfiler.current = c
    end


    def config
      @config
    end


    def call(env)

      client_settings = ClientSettings.new(env)

      status = headers = body = nil
      query_string = env['QUERY_STRING']
      path         = env['PATH_INFO']

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

      if query_string =~ /pp=enable/ && (@config.authorization_mode != :whitelist || MiniProfiler.request_authorized?)
        skip_it = false
        config.enabled = true
      end

      if skip_it || !config.enabled
        status,headers,body = @app.call(env)
        client_settings.disable_profiling = true
        client_settings.write!(headers)
        return [status,headers,body]
      else
        client_settings.disable_profiling = false
      end

      if query_string =~ /pp=profile-gc/
        current.measure = false if current

        if query_string =~ /pp=profile-gc-time/
          return Rack::MiniProfiler::GCProfiler.new.profile_gc_time(@app, env)
        elsif query_string =~ /pp=profile-gc-ruby-head/
          result = StringIO.new
          report = MemoryProfiler.report do
            _,_,body = @app.call(env)
            body.close if body.respond_to? :close
          end
          report.pretty_print(result)
          return text_result(result.string)
        else
          return Rack::MiniProfiler::GCProfiler.new.profile_gc(@app, env)
        end
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

      flamegraph = nil

      trace_exceptions = query_string =~ /pp=trace-exceptions/ && defined? TracePoint
      status, headers, body, exceptions,trace = nil

      start = Time.now

      if trace_exceptions
        exceptions = []
        trace      = TracePoint.new(:raise) do |tp|
          exceptions << tp.raised_exception
        end
        trace.enable
      end

      begin

        # Strip all the caching headers so we don't get 304s back
        #  This solves a very annoying bug where rack mini profiler never shows up
        if config.disable_caching
          env['HTTP_IF_MODIFIED_SINCE'] = ''
          env['HTTP_IF_NONE_MATCH']     = ''
        end

        if query_string =~ /pp=flamegraph/
          unless defined?(Flamegraph) && Flamegraph.respond_to?(:generate)

            flamegraph = "Please install the flamegraph gem and require it: add gem 'flamegraph' to your Gemfile"
            status,headers,body = @app.call(env)
          else
            # do not sully our profile with mini profiler timings
            current.measure = false
            match_data      = query_string.match(/flamegraph_sample_rate=([\d\.]+)/)

            mode = query_string =~ /mode=c/ ? :c : :ruby

            if match_data && !match_data[1].to_f.zero?
              sample_rate = match_data[1].to_f
            else
              sample_rate = config.flamegraph_sample_rate
            end
            flamegraph = Flamegraph.generate(nil, :fidelity => sample_rate, :embed_resources => query_string =~ /embed/, :mode => mode) do
              status,headers,body = @app.call(env)
            end
          end
        else
          status,headers,body = @app.call(env)
        end
        client_settings.write!(headers)
      ensure
        trace.disable if trace
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
      if trace_exceptions
        body.close if body.respond_to? :close
        return dump_exceptions exceptions
      end

      if query_string =~ /pp=env/
        body.close if body.respond_to? :close
        return dump_env env
      end

      if query_string =~ /pp=help/
        body.close if body.respond_to? :close
        return help(client_settings)
      end

      page_struct = current.page_struct
      page_struct[:user] = user(env)
      page_struct[:root].record_time((Time.now - start) * 1000)

      if flamegraph
        body.close if body.respond_to? :close
        return self.flamegraph(flamegraph)
      end


      begin
        # no matter what it is, it should be unviewed, otherwise we will miss POST
        @storage.set_unviewed(page_struct[:user], page_struct[:id])
        @storage.save(page_struct)

        # inject headers, script
        if headers['Content-Type'] && status == 200
          client_settings.write!(headers)
          result = inject_profiler(env,status,headers,body)
          return result if result
        end
      rescue Exception => e
        if @config.storage_failure != nil
          @config.storage_failure.call(e)
        end
      end

      client_settings.write!(headers)
      [status, headers, body]

    ensure
      # Make sure this always happens
      self.current = nil
    end

    def inject_profiler(env,status,headers,body)
      # mini profiler is meddling with stuff, we can not cache cause we will get incorrect data
      # Rack::ETag has already inserted some nonesense in the chain
      content_type = headers['Content-Type']

      if config.disable_caching
        headers.delete('ETag')
        headers.delete('Date')
      end

      headers['Cache-Control'] = "#{"no-store, " if config.disable_caching}must-revalidate, private, max-age=0"

      # inject header
      if headers.is_a? Hash
        headers['X-MiniProfiler-Ids'] = ids_json(env)
      end

      if current.inject_js && content_type =~ /text\/html/
        response = Rack::Response.new([], status, headers)
        script   = self.get_profile_script(env)

        if String === body
          response.write inject(body,script)
        else
          body.each { |fragment| response.write inject(fragment, script) }
        end
        body.close if body.respond_to? :close
        response.finish
      else
        nil
      end
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
        # implicit </body> and </html>. Don't do anything.

        return fragment
      end

      matches = fragment.scan(regex).length
      index = 1
      fragment.gsub(regex) do
        # though malformed there is an edge case where /body exists earlier in the html, work around
        if index < matches
          index += 1
          close_tag
        else

          # if for whatever crazy reason we dont get a utf string,
          #   just force the encoding, no utf in the mp scripts anyway
          if script.respond_to?(:encoding) && script.respond_to?(:force_encoding)
            (script + close_tag).force_encoding(fragment.encoding)
          else
            script + close_tag
          end
        end
      end
    end

    def dump_exceptions(exceptions)
      headers = {'Content-Type' => 'text/plain'}
      body    = "Exceptions (#{exceptions.length} raised during request)\n\n"
      exceptions.each do |e|
        body << "#{e.class} #{e.message}\n#{e.backtrace.join("\n")}\n\n\n\n"
      end

      [200, headers, [body]]
    end

    def dump_env(env)
      body = "Rack Environment\n---------------\n"
      env.each do |k,v|
        body << "#{k}: #{v}\n"
      end

      body << "\n\nEnvironment\n---------------\n"
      ENV.each do |k,v|
        body << "#{k}: #{v}\n"
      end

      body << "\n\nRuby Version\n---------------\n"
      body << "#{RUBY_VERSION} p#{RUBY_PATCHLEVEL}\n"

      body << "\n\nInternals\n---------------\n"
      body << "Storage Provider #{config.storage_instance}\n"
      body << "User #{user(env)}\n"
      body << config.storage_instance.diagnostics(user(env)) rescue "no diagnostics implemented for storage"

      text_result(body)
    end

    def text_result(body)
      headers = {'Content-Type' => 'text/plain'}
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
  pp=disable : disable profiling for this session
  pp=enable : enable profiling for this session (if previously disabled)
  pp=profile-gc: perform gc profiling on this request, analyzes ObjectSpace generated by request (ruby 1.9.3 only)
  pp=profile-gc-time: perform built-in gc profiling on this request (ruby 1.9.3 only)
  pp=profile-gc-ruby-head: requires the memory_profiler gem, new location based report
  pp=flamegraph: works best on Ruby 2.0, a graph representing sampled activity (requires the flamegraph gem).
  pp=flamegraph&flamegraph_sample_rate=1: creates a flamegraph with the specified sample rate (in ms). Overrides value set in config
  pp=flamegraph_embed: works best on Ruby 2.0, a graph representing sampled activity (requires the flamegraph gem), embedded resources for use on an intranet.
  pp=trace-exceptions: requires Ruby 2.0, will return all the spots where your application raises execptions
"

      client_settings.write!(headers)
      [200, headers, [body]]
    end

    def flamegraph(graph)
      headers = {'Content-Type' => 'text/html'}
      [200, headers, [graph]]
    end

    def ids(env)
      # cap at 10 ids, otherwise there is a chance you can blow the header
      ([current.page_struct[:id]] + (@storage.get_unviewed_ids(user(env)) || [])[0..8]).uniq
    end

    def ids_json(env)
      ::JSON.generate(ids(env))
    end

    def ids_comma_separated(env)
      ids(env).join(",")
    end

    # get_profile_script returns script to be injected inside current html page
    # By default, profile_script is appended to the end of all html requests automatically.
    # Calling get_profile_script cancels automatic append for the current page
    # Use it when:
    # * you have disabled auto append behaviour throught :auto_inject => false flag
    # * you do not want script to be automatically appended for the current page. You can also call cancel_auto_inject
    def get_profile_script(env)
      path     = "#{env['SCRIPT_NAME']}#{@config.base_url_path}"

      settings = {
       :path            => path,
       :version         => MiniProfiler::ASSET_VERSION,
       :position        => @config.position,
       :showTrivial     => false,
       :showChildren    => false,
       :maxTracesToShow => 10,
       :showControls    => false,
       :authorized      => true,
       :toggleShortcut  => @config.toggle_shortcut,
       :startHidden     => @config.start_hidden
      }

      if current && current.page_struct
        settings[:ids]       = ids_comma_separated(env)
        settings[:currentId] = current.page_struct[:id]
      else
        settings[:ids]       = []
        settings[:currentId] = ""
      end

      # TODO : cache this snippet
      script = IO.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
      # replace the variables
      settings.each do |k,v|
        regex = Regexp.new("\\{#{k.to_s}\\}")
        script.gsub!(regex, v.to_s)
      end

      current.inject_js = false if current
      script
    end

    # cancels automatic injection of profile script for the current page
    def cancel_auto_inject(env)
      current.inject_js = false
    end

  end
end
