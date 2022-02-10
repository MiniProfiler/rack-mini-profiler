# frozen_string_literal: true

require 'cgi'

module Rack
  class MiniProfiler
    class << self

      include Rack::MiniProfiler::ProfilingMethods
      attr_accessor :subscribe_sql_active_record

      def patch_rails?
        !!defined?(Rack::MINI_PROFILER_ENABLE_RAILS_PATCHES)
      end

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

      def resources_root
        @resources_root ||= ::File.expand_path("../../html", __FILE__)
      end

      def share_template
        @share_template ||= ERB.new(::File.read(::File.expand_path("../html/share.html", ::File.dirname(__FILE__))))
      end

      def current
        Thread.current[:mini_profiler_private]
      end

      def current=(c)
        # we use TLS cause we need access to this from sql blocks and code blocks that have no access to env
        Thread.current[:mini_profiler_snapshot_custom_fields] = nil
        Thread.current[:mp_ongoing_snapshot] = nil
        Thread.current[:mini_profiler_private] = c
      end

      def add_snapshot_custom_field(key, value)
        thread_var_key = :mini_profiler_snapshot_custom_fields
        Thread.current[thread_var_key] ||= {}
        Thread.current[thread_var_key][key] = value
      end

      def get_snapshot_custom_fields
        Thread.current[:mini_profiler_snapshot_custom_fields]
      end

      # discard existing results, don't track this request
      def discard_results
        self.current.discard = true if current
      end

      def create_current(env = {}, options = {})
        # profiling the request
        context               = Context.new
        context.inject_js     = config.auto_inject && (!env['HTTP_X_REQUESTED_WITH'].eql? 'XMLHttpRequest')
        context.page_struct   = TimerStruct::Page.new(env)
        context.current_timer = context.page_struct[:root]
        self.current          = context
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

      def advanced_tools_message
        <<~TEXT
          This feature is disabled by default, to enable set the enable_advanced_debugging_tools option to true in Mini Profiler config.
        TEXT
      end

      def binds_to_params(binds)
        return if binds.nil? || config.max_sql_param_length == 0
        # map ActiveRecord::Relation::QueryAttribute to [name, value]
        params = binds.map { |c| c.kind_of?(Array) ? [c.first, c.last] : [c.name, c.value] }
        if (skip = config.skip_sql_param_names)
          params.map { |(n, v)| n =~ skip ? [n, nil] : [n, v] }
        else
          params
        end
      end

      def snapshots_transporter?
        !!config.snapshots_transport_destination_url &&
        !!config.snapshots_transport_auth_key
      end

      def redact_sql_queries?
        Thread.current[:mp_ongoing_snapshot] == true &&
        Rack::MiniProfiler.config.snapshots_redact_sql_queries
      end
    end

    #
    # options:
    # :auto_inject - should script be automatically injected on every html page (not xhr)
    def initialize(app, config = nil)
      MiniProfiler.config.merge!(config)
      @config = MiniProfiler.config
      @app    = app
      @config.base_url_path += "/" unless @config.base_url_path.end_with? "/"
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
      id          = request.params['id']
      is_snapshot = request.params['snapshot']
      is_snapshot = [true, "true"].include?(is_snapshot)
      if is_snapshot
        page_struct = @storage.load_snapshot(id)
      else
        page_struct = @storage.load(id)
      end
      if !page_struct && is_snapshot
        id = ERB::Util.html_escape(id)
        return [404, {}, ["Snapshot with id '#{id}' not found"]]
      elsif !page_struct
        @storage.set_viewed(user(env), id)
        id        = ERB::Util.html_escape(id)
        user_info = ERB::Util.html_escape(user(env))
        return [404, {}, ["Request not found: #{id} - user #{user_info}"]]
      end
      if !page_struct[:has_user_viewed] && !is_snapshot
        page_struct[:client_timings]  = TimerStruct::Client.init_from_form_data(env, page_struct)
        page_struct[:has_user_viewed] = true
        @storage.save(page_struct)
        @storage.set_viewed(user(env), id)
      end

      # If we're an XMLHttpRequest, serve up the contents as JSON
      if request.xhr?
        result_json = page_struct.to_json
        [200, { 'Content-Type' => 'application/json' }, [result_json]]
      else
        # Otherwise give the HTML back
        html = generate_html(page_struct, env)
        [200, { 'Content-Type' => 'text/html' }, [html]]
      end
    end

    def generate_html(page_struct, env, result_json = page_struct.to_json)
      # double-assigning to suppress "assigned but unused variable" warnings
      path = path = "#{env['RACK_MINI_PROFILER_ORIGINAL_SCRIPT_NAME']}#{@config.base_url_path}"
      version = version = MiniProfiler::ASSET_VERSION
      json = json = result_json
      includes = includes = get_profile_script(env)
      name = name = page_struct[:name]
      duration = duration = page_struct.duration_ms.round(1).to_s

      MiniProfiler.share_template.result(binding)
    end

    def serve_html(env)
      path      = env['PATH_INFO'].sub('//', '/')
      file_name = path.sub(@config.base_url_path, '')

      return serve_results(env) if file_name.eql?('results')
      return handle_snapshots_request(env) if file_name.eql?('snapshots')
      return serve_flamegraph(env) if file_name.eql?('flamegraph')

      resources_env = env.dup
      resources_env['PATH_INFO'] = file_name

      rack_file = Rack::File.new(MiniProfiler.resources_root, 'Cache-Control' => "max-age=#{cache_control_value}")
      rack_file.call(resources_env)
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

    def advanced_debugging_enabled?
      config.enable_advanced_debugging_tools
    end

    def tool_disabled_message(client_settings)
      client_settings.handle_cookie(text_result(Rack::MiniProfiler.advanced_tools_message))
    end

    def call(env)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      client_settings = ClientSettings.new(env, @storage, start)
      MiniProfiler.deauthorize_request if @config.authorization_mode == :allow_authorized

      status = headers = body = nil
      query_string = env['QUERY_STRING']
      path         = env['PATH_INFO'].sub('//', '/')

      # Someone (e.g. Rails engine) could change the SCRIPT_NAME so we save it
      env['RACK_MINI_PROFILER_ORIGINAL_SCRIPT_NAME'] = ENV['PASSENGER_BASE_URI'] || env['SCRIPT_NAME']

      skip_it = /pp=skip/.match?(query_string) || (
        @config.skip_paths &&
        @config.skip_paths.any? do |p|
          if p.instance_of?(String)
            path.start_with?(p)
          elsif p.instance_of?(Regexp)
            p.match?(path)
          end
        end
      )
      if skip_it
        return client_settings.handle_cookie(@app.call(env))
      end

      skip_it = (@config.pre_authorize_cb && !@config.pre_authorize_cb.call(env))

      if skip_it || (
        @config.authorization_mode == :allow_authorized &&
        !client_settings.has_valid_cookie?
      )
        if take_snapshot?(path)
          return client_settings.handle_cookie(take_snapshot(env, start))
        else
          return client_settings.handle_cookie(@app.call(env))
        end
      end

      # handle all /mini-profiler requests here
      return client_settings.handle_cookie(serve_html(env)) if path.start_with? @config.base_url_path

      has_disable_cookie = client_settings.disable_profiling?
      # manual session disable / enable
      if query_string =~ /pp=disable/ || has_disable_cookie
        skip_it = true
      end

      if query_string =~ /pp=enable/
        skip_it = false
        config.enabled = true
      end

      if skip_it || !config.enabled
        status, headers, body = @app.call(env)
        client_settings.disable_profiling = true
        return client_settings.handle_cookie([status, headers, body])
      else
        client_settings.disable_profiling = false
      end

      # profile gc
      if query_string =~ /pp=profile-gc/
        return tool_disabled_message(client_settings) if !advanced_debugging_enabled?
        current.measure = false if current
        return client_settings.handle_cookie(Rack::MiniProfiler::GCProfiler.new.profile_gc(@app, env))
      end

      # profile memory
      if query_string =~ /pp=profile-memory/
        return tool_disabled_message(client_settings) if !advanced_debugging_enabled?

        unless defined?(MemoryProfiler) && MemoryProfiler.respond_to?(:report)
          message = "Please install the memory_profiler gem and require it: add gem 'memory_profiler' to your Gemfile"
          _, _, body = @app.call(env)
          body.close if body.respond_to? :close

          return client_settings.handle_cookie(text_result(message))
        end

        query_params = Rack::Utils.parse_nested_query(query_string)
        options = {
          ignore_files: query_params['memory_profiler_ignore_files'],
          allow_files: query_params['memory_profiler_allow_files'],
        }
        options[:top] = Integer(query_params['memory_profiler_top']) if query_params.key?('memory_profiler_top')
        result = StringIO.new
        report = MemoryProfiler.report(options) do
          _, _, body = @app.call(env)
          body.close if body.respond_to? :close
        end
        report.pretty_print(result)
        return client_settings.handle_cookie(text_result(result.string))
      end

      MiniProfiler.create_current(env, @config)

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
      status, headers, body, exceptions, trace = nil

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

        orig_accept_encoding = env['HTTP_ACCEPT_ENCODING']
        # Prevent response body from being compressed
        env['HTTP_ACCEPT_ENCODING'] = 'identity' if config.suppress_encoding

        if query_string =~ /pp=(async-)?flamegraph/ || env['HTTP_REFERER'] =~ /pp=async-flamegraph/
          unless defined?(StackProf) && StackProf.respond_to?(:run)
            headers = { 'Content-Type' => 'text/html' }
            message = "Please install the stackprof gem and require it: add gem 'stackprof' to your Gemfile"
            body.close if body.respond_to? :close
            return client_settings.handle_cookie([500, headers, message])
          else
            # do not sully our profile with mini profiler timings
            current.measure = false
            match_data      = query_string.match(/flamegraph_sample_rate=([\d\.]+)/)

            if match_data && !match_data[1].to_f.zero?
              sample_rate = match_data[1].to_f
            else
              sample_rate = config.flamegraph_sample_rate
            end

            mode_match_data = query_string.match(/flamegraph_mode=([a-zA-Z]+)/)

            if mode_match_data && [:cpu, :wall, :object, :custom].include?(mode_match_data[1].to_sym)
              mode = mode_match_data[1].to_sym
            else
              mode = config.flamegraph_mode
            end

            flamegraph = StackProf.run(
              mode: mode,
              raw: true,
              aggregate: false,
              interval: (sample_rate * 1000).to_i
            ) do
              status, headers, body = @app.call(env)
            end
          end
        elsif path == '/rack-mini-profiler/requests'
          blank_page_html = <<~HTML
            <html>
              <head></head>
              <body></body>
            </html>
          HTML

          status, headers, body = [200, { 'Content-Type' => 'text/html' }, [blank_page_html.dup]]
        else
          status, headers, body = @app.call(env)
        end
      ensure
        trace.disable if trace
        env['HTTP_ACCEPT_ENCODING'] = orig_accept_encoding if config.suppress_encoding
      end

      skip_it = current.discard

      if (config.authorization_mode == :allow_authorized && !MiniProfiler.request_authorized?)
        skip_it = true
      end

      return client_settings.handle_cookie([status, headers, body]) if skip_it

      # we must do this here, otherwise current[:discard] is not being properly treated
      if trace_exceptions
        body.close if body.respond_to? :close

        query_params = Rack::Utils.parse_nested_query(query_string)
        trace_exceptions_filter = query_params['trace_exceptions_filter']
        if trace_exceptions_filter
          trace_exceptions_regex = Regexp.new(trace_exceptions_filter)
          exceptions.reject! { |ex| ex.class.name =~ trace_exceptions_regex }
        end

        return client_settings.handle_cookie(dump_exceptions exceptions)
      end

      if query_string =~ /pp=env/
        return tool_disabled_message(client_settings) if !advanced_debugging_enabled?
        body.close if body.respond_to? :close
        return client_settings.handle_cookie(dump_env env)
      end

      if query_string =~ /pp=analyze-memory/
        return tool_disabled_message(client_settings) if !advanced_debugging_enabled?
        body.close if body.respond_to? :close
        return client_settings.handle_cookie(analyze_memory)
      end

      if query_string =~ /pp=help/
        body.close if body.respond_to? :close
        return client_settings.handle_cookie(help(client_settings, env))
      end

      page_struct = current.page_struct
      page_struct[:user] = user(env)
      page_struct[:root].record_time((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000)

      if flamegraph && query_string =~ /pp=flamegraph/
        body.close if body.respond_to? :close
        return client_settings.handle_cookie(self.flamegraph(flamegraph, path))
      elsif flamegraph # async-flamegraph
        page_struct[:has_flamegraph] = true
        page_struct[:flamegraph] = flamegraph
      end

      begin
        @storage.save(page_struct)
        # no matter what it is, it should be unviewed, otherwise we will miss POST
        @storage.set_unviewed(page_struct[:user], page_struct[:id])

        # inject headers, script
        if status >= 200 && status < 300
          result = inject_profiler(env, status, headers, body)
          return client_settings.handle_cookie(result) if result
        end
      rescue Exception => e
        if @config.storage_failure != nil
          @config.storage_failure.call(e)
        end
      end

      client_settings.handle_cookie([status, headers, body])

    ensure
      # Make sure this always happens
      self.current = nil
    end

    def inject_profiler(env, status, headers, body)
      # mini profiler is meddling with stuff, we can not cache cause we will get incorrect data
      # Rack::ETag has already inserted some nonesense in the chain
      content_type = headers['Content-Type']

      if config.disable_caching
        headers.delete('ETag')
        headers.delete('Date')
      end

      headers['X-MiniProfiler-Original-Cache-Control'] = headers['Cache-Control'] unless headers['Cache-Control'].nil?
      headers['Cache-Control'] = "#{"no-store, " if config.disable_caching}must-revalidate, private, max-age=0"

      # inject header
      if headers.is_a? Hash
        headers['X-MiniProfiler-Ids'] = ids_comma_separated(env)
      end

      if current.inject_js && content_type =~ /text\/html/
        response = Rack::Response.new([], status, headers)
        script   = self.get_profile_script(env)

        if String === body
          response.write inject(body, script)
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
      # find explicit or implicit body
      index = fragment.rindex(/<\/body>/i) || fragment.rindex(/<\/html>/i)
      if index
        # if for whatever crazy reason we dont get a utf string,
        #   just force the encoding, no utf in the mp scripts anyway
        if script.respond_to?(:encoding) && script.respond_to?(:force_encoding)
          script = script.force_encoding(fragment.encoding)
        end

        safe_script = script
        if script.respond_to?(:html_safe)
          safe_script = script.html_safe
        end

        fragment.insert(index, safe_script)
      else
        fragment
      end
    end

    def dump_exceptions(exceptions)
      body = "Exceptions raised during request\n\n".dup
      if exceptions.empty?
        body << "No exceptions raised"
      else
        body << "Exceptions: (#{exceptions.size} total)\n"
        exceptions.group_by(&:class).each do |klass, exceptions_per_class|
          body << "  #{klass.name} (#{exceptions_per_class.size})\n"
        end

        body << "\nBacktraces\n"
        exceptions.each_with_index do |e, i|
          body << "##{i + 1}: #{e.class} - \"#{e.message}\"\n  #{e.backtrace.join("\n  ")}\n\n"
        end
      end
      text_result(body)
    end

    def dump_env(env)
      body = "Rack Environment\n---------------\n".dup
      env.each do |k, v|
        body << "#{k}: #{v}\n"
      end

      body << "\n\nEnvironment\n---------------\n"
      ENV.each do |k, v|
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

    def trim_strings(strings, max_size)
      strings.sort! { |a, b| b[1] <=> a[1] }
      i = 0
      strings.delete_if { |_| (i += 1) > max_size }
    end

    def analyze_memory
      require 'objspace'

      utf8 = "utf-8"

      GC.start

      trunc = lambda do |str|
        str = str.length > 200 ? str : str[0..200]

        if str.encoding != Encoding::UTF_8
          str = str.dup
          str.force_encoding(utf8)

          unless str.valid_encoding?
            # work around bust string with a double conversion
            str.encode!("utf-16", "utf-8", invalid: :replace)
            str.encode!("utf-8", "utf-16")
          end
        end

        str
      end

      body = "ObjectSpace stats:\n\n".dup

      counts = ObjectSpace.count_objects
      total_strings = counts[:T_STRING]

      body << counts
        .sort { |a, b| b[1] <=> a[1] }
        .map { |k, v| "#{k}: #{v}" }
        .join("\n")

      strings = []
      string_counts = Hash.new(0)
      sample_strings = []

      max_size = 1000
      sample_every = total_strings / max_size

      i = 0
      ObjectSpace.each_object(String) do |str|
        i += 1
        string_counts[str] += 1
        strings << [trunc.call(str), str.length]
        sample_strings << [trunc.call(str), str.length] if i % sample_every == 0
        if strings.length > max_size * 2
          trim_strings(strings, max_size)
        end
      end

      trim_strings(strings, max_size)

      body << "\n\n\n1000 Largest strings:\n\n"
      body << strings.map { |s, len| "#{s[0..1000]}\n(len: #{len})\n\n" }.join("\n")

      body << "\n\n\n1000 Sample strings:\n\n"
      body << sample_strings.map { |s, len| "#{s[0..1000]}\n(len: #{len})\n\n" }.join("\n")

      body << "\n\n\n1000 Most common strings:\n\n"
      body << string_counts.sort { |a, b| b[1] <=> a[1] }[0..max_size].map { |s, len| "#{trunc.call(s)}\n(x #{len})\n\n" }.join("\n")

      text_result(body)
    end

    def text_result(body)
      headers = { 'Content-Type' => 'text/plain; charset=utf-8' }
      [200, headers, [body]]
    end

    def make_link(postfix, env)
      link = env["PATH_INFO"] + "?" + env["QUERY_STRING"].sub("pp=help", "pp=#{postfix}")
      "pp=<a href='#{ERB::Util.html_escape(link)}'>#{postfix}</a>"
    end

    def help(client_settings, env)
      headers = { 'Content-Type' => 'text/html' }
      body = "<html><body>
<pre style='line-height: 30px; font-size: 16px;'>
This is the help menu of the <a href='#{Rack::MiniProfiler::SOURCE_CODE_URI}'>rack-mini-profiler</a> gem, append the following to your query string for more options:

  #{make_link "help", env} : display this screen
  #{make_link "env", env} : display the rack environment
  #{make_link "skip", env} : skip mini profiler for this request
  #{make_link "no-backtrace", env} #{"(*) " if client_settings.backtrace_none?}: don't collect stack traces from all the SQL executed (sticky, use pp=normal-backtrace to enable)
  #{make_link "normal-backtrace", env} #{"(*) " if client_settings.backtrace_default?}: collect stack traces from all the SQL executed and filter normally
  #{make_link "full-backtrace", env} #{"(*) " if client_settings.backtrace_full?}: enable full backtraces for SQL executed (use pp=normal-backtrace to disable)
  #{make_link "disable", env} : disable profiling for this session
  #{make_link "enable", env} : enable profiling for this session (if previously disabled)
  #{make_link "profile-gc", env} : perform gc profiling on this request, analyzes ObjectSpace generated by request
  #{make_link "profile-memory", env} : requires the memory_profiler gem, new location based report
  #{make_link "flamegraph", env} : a graph representing sampled activity (requires the stackprof gem).
  #{make_link "async-flamegraph", env} : store flamegraph data for this page and all its AJAX requests. Flamegraph links will be available in the mini-profiler UI (requires the stackprof gem).
  #{make_link "flamegraph&flamegraph_sample_rate=1", env}: creates a flamegraph with the specified sample rate (in ms). Overrides value set in config
  #{make_link "flamegraph&flamegraph_mode=cpu", env}: creates a flamegraph with the specified mode (one of cpu, wall, object, or custom). Overrides value set in config
  #{make_link "flamegraph_embed", env} : a graph representing sampled activity (requires the stackprof gem), embedded resources for use on an intranet.
  #{make_link "trace-exceptions", env} : will return all the spots where your application raises exceptions
  #{make_link "analyze-memory", env} : will perform basic memory analysis of heap
</pre>
</body>
</html>
"

      [200, headers, [body]]
    end

    def flamegraph(graph, path)
      headers = { 'Content-Type' => 'text/html' }
      html = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <style>
              body { margin: 0; height: 100vh; }
              #speedscope-iframe { width: 100%; height: 100%; border: none; }
            </style>
          </head>
          <body>
            <script type="text/javascript">
              var graph = #{JSON.generate(graph)};
              var json = JSON.stringify(graph);
              var blob = new Blob([json], { type: 'text/plain' });
              var objUrl = encodeURIComponent(URL.createObjectURL(blob));
              var iframe = document.createElement('IFRAME');
              iframe.setAttribute('id', 'speedscope-iframe');
              document.body.appendChild(iframe);
              var iframeUrl = '#{@config.base_url_path}speedscope/index.html#profileURL=' + objUrl + '&title=' + 'Flamegraph for #{CGI.escape(path)}';
              iframe.setAttribute('src', iframeUrl);
            </script>
          </body>
        </html>
      HTML
      [200, headers, [html]]
    end

    def ids(env)
      all = ([current.page_struct[:id]] + (@storage.get_unviewed_ids(user(env)) || [])).uniq
      if all.size > @config.max_traces_to_show
        all = all[0...@config.max_traces_to_show]
        @storage.set_all_unviewed(user(env), all)
      end
      all
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
      path = "#{env['RACK_MINI_PROFILER_ORIGINAL_SCRIPT_NAME']}#{@config.base_url_path}"
      version = MiniProfiler::ASSET_VERSION
      if @config.assets_url
        url = @config.assets_url.call('rack-mini-profiler.js', version, env)
        css_url = @config.assets_url.call('rack-mini-profiler.css', version, env)
      end

      url = "#{path}includes.js?v=#{version}" if !url
      css_url = "#{path}includes.css?v=#{version}" if !css_url

      content_security_policy_nonce = @config.content_security_policy_nonce ||
                                      env["action_dispatch.content_security_policy_nonce"] ||
                                      env["secure_headers_content_security_policy_nonce"]

      settings = {
       path: path,
       url: url,
       cssUrl: css_url,
       version: version,
       verticalPosition: @config.vertical_position,
       horizontalPosition: @config.horizontal_position,
       showTrivial: @config.show_trivial,
       showChildren: @config.show_children,
       maxTracesToShow: @config.max_traces_to_show,
       showControls: @config.show_controls,
       showTotalSqlCount: @config.show_total_sql_count,
       authorized: true,
       toggleShortcut: @config.toggle_shortcut,
       startHidden: @config.start_hidden,
       collapseResults: @config.collapse_results,
       htmlContainer: @config.html_container,
       hiddenCustomFields: @config.snapshot_hidden_custom_fields.join(','),
       cspNonce: content_security_policy_nonce,
       hotwireTurboDriveSupport: @config.enable_hotwire_turbo_drive_support,
      }

      if current && current.page_struct
        settings[:ids]       = ids_comma_separated(env)
        settings[:currentId] = current.page_struct[:id]
      else
        settings[:ids]       = []
        settings[:currentId] = ""
      end

      # TODO : cache this snippet
      script = ::File.read(::File.expand_path('../html/profile_handler.js', ::File.dirname(__FILE__)))
      # replace the variables
      settings.each do |k, v|
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

    def cache_control_value
      86400
    end

    private

    def handle_snapshots_request(env)
      self.current = nil
      MiniProfiler.authorize_request
      status = 200
      headers = { 'Content-Type' => 'text/html' }
      qp = Rack::Utils.parse_nested_query(env['QUERY_STRING'])
      if group_name = qp["group_name"]
        list = @storage.find_snapshots_group(group_name)
        list.each do |snapshot|
          snapshot[:url] = url_for_snapshot(snapshot[:id])
        end
        data = {
          group_name: group_name,
          list: list
        }
      else
        list = @storage.snapshot_groups_overview
        list.each do |group|
          group[:url] = url_for_snapshots_group(group[:name])
        end
        data = {
          page: "overview",
          list: list
        }
      end
      data_html = <<~HTML
        <div style="display: none;" id="snapshots-data">
        #{data.to_json}
        </div>
      HTML
      response = Rack::Response.new([], status, headers)

      response.write <<~HTML
        <html>
          <head></head>
          <body class="mp-snapshots">
      HTML
      response.write(data_html)
      script = self.get_profile_script(env)
      response.write(script)
      response.write <<~HTML
          </body>
        </html>
      HTML
      response.finish
    end

    def serve_flamegraph(env)
      request     = Rack::Request.new(env)
      id          = request.params['id']
      page_struct = @storage.load(id)

      if !page_struct
        id        = ERB::Util.html_escape(id)
        user_info = ERB::Util.html_escape(user(env))
        return [404, {}, ["Request not found: #{id} - user #{user_info}"]]
      end

      if !page_struct[:flamegraph]
        return [404, {}, ["No flamegraph available for #{ERB::Util.html_escape(id)}"]]
      end

      self.flamegraph(page_struct[:flamegraph], page_struct[:request_path])
    end

    def rails_route_from_path(path, method)
      if defined?(Rails) && defined?(ActionController::RoutingError)
        hash = Rails.application.routes.recognize_path(path, method: method)
        if hash && hash[:controller] && hash[:action]
          "#{method} #{hash[:controller]}##{hash[:action]}"
        end
      end
    rescue ActionController::RoutingError
      nil
    end

    def url_for_snapshots_group(group_name)
      qs = Rack::Utils.build_query({ group_name: group_name })
      "/#{@config.base_url_path.gsub('/', '')}/snapshots?#{qs}"
    end

    def url_for_snapshot(id)
      qs = Rack::Utils.build_query({ id: id, snapshot: true })
      "/#{@config.base_url_path.gsub('/', '')}/results?#{qs}"
    end

    def take_snapshot?(path)
      @config.snapshot_every_n_requests > 0 &&
      !path.start_with?(@config.base_url_path) &&
      @storage.should_take_snapshot?(@config.snapshot_every_n_requests)
    end

    def take_snapshot(env, start)
      MiniProfiler.create_current(env, @config)
      Thread.current[:mp_ongoing_snapshot] = true
      results = @app.call(env)
      status = results[0].to_i
      if status >= 200 && status < 300
        page_struct = current.page_struct
        page_struct[:root].record_time(
          (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000
        )
        custom_fields = MiniProfiler.get_snapshot_custom_fields
        page_struct[:custom_fields] = custom_fields if custom_fields
        if Rack::MiniProfiler.snapshots_transporter?
          Rack::MiniProfiler::SnapshotsTransporter.transport(page_struct)
        else
          @storage.push_snapshot(
            page_struct,
            @config
          )
        end
      end
      self.current = nil
      results
    end
  end
end
