module Rack
  class MiniProfiler
    module HTML
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

      def serve_snapshot_request(env)
        self.current = nil
        MiniProfiler.authorize_request
        status = 200
        headers = { 'Content-Type' => 'text/html' }
        qp = Rack::Utils.parse_nested_query(env['QUERY_STRING'])
        if group_name = qp["group_name"]
          list = @storage.snapshots_group(group_name)
          list.each do |snapshot|
            snapshot[:url] = url_for_snapshot(snapshot[:id], group_name)
          end
          data = {
            group_name: group_name,
            list: list
          }
        else
          list = @storage.snapshots_overview
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
          <!DOCTYPE html>
          <html>
            <head>
              <title>Rack::MiniProfiler Snapshots</title>
            </head>
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

      def serve_html(env)
        path      = env['PATH_INFO'].sub('//', '/')
        file_name = path.sub(@config.base_url_path, '')

        return serve_results(env) if file_name.eql?('results')
        return serve_snapshot_request(env) if file_name.eql?('snapshots')
        return serve_flamegraph(env) if file_name.eql?('flamegraph')

        resources_env = env.dup
        resources_env['PATH_INFO'] = file_name

        rack_file = Rack::File.new(MiniProfiler.resources_root, 'Cache-Control' => "max-age=#{cache_control_value}")
        rack_file.call(resources_env)
      end

      # get_profile_script returns script to be injected inside current html page
      # By default, profile_script is appended to the end of all html requests automatically.
      # Calling get_profile_script cancels automatic append for the current page
      # Use it when:
      # * you have disabled auto append behaviour throught :auto_inject => false flag
      # * you do not want script to be automatically appended for the current page. You can also call cancel_auto_inject
      def get_profile_script(env)
        path = public_base_path(env)
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


      BLANK_PAGE = <<~HTML
        <!DOCTYPE html>
        <html>
          <head>
            <title>Rack::MiniProfiler Requests</title>
          </head>
          <body>
          </body>
        </html>
      HTML
      def blank_page_html
        BLANK_PAGE
      end
    end
  end
end
