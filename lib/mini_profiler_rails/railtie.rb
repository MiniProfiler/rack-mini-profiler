require 'fileutils'

module Rack::MiniProfilerRails

  # call direct if needed to do a defer init
  def self.initialize!(app)
    
    raise "MiniProfilerRails initialized twice. Set `require: false' for rack-mini-profiler in your Gemfile" if @already_initialized
      
    c = Rack::MiniProfiler.config

    # By default, only show the MiniProfiler in development mode, in production allow profiling if post_authorize_cb is set
    #
    # NOTE: this must be set here with = and not ||=
    #  The out of the box default is "true"
    c.pre_authorize_cb = lambda { |env|
      !Rails.env.test?
    }

    c.skip_paths ||= []

    if Rails.env.development?
      c.skip_paths << app.config.assets.prefix if app.respond_to? :assets
      c.skip_schema_queries = true
    end

    unless Rails.env.development? || Rails.env.test?
      c.authorization_mode = :whitelist
    end

    if Rails.logger
      c.logger = Rails.logger
    end

    # The file store is just so much less flaky
    base_path = Rails.application.config.paths['tmp'].first rescue "#{Rails.root}/tmp"
    tmp       = base_path + '/miniprofiler'
    FileUtils.mkdir_p(tmp) unless File.exists?(tmp)

    c.storage_options = {:path => tmp}
    c.storage = Rack::MiniProfiler::FileStore

    # Quiet the SQL stack traces
    c.backtrace_remove = Rails.root.to_s + "/"
    c.backtrace_includes =  [/^\/?(app|config|lib|test)/]
    c.skip_schema_queries = (Rails.env.development? || Rails.env.test?)

    # Install the Middleware
    app.middleware.insert(0, Rack::MiniProfiler)

    # Attach to various Rails methods
    ActiveSupport.on_load(:action_controller) do
      ::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "Executing action: #{action}"}
    end
    ActiveSupport.on_load(:action_view) do
      ::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{@virtual_path}"}
    end
    
    @already_initialized = true
  end

  class Railtie < ::Rails::Railtie

    initializer "rack_mini_profiler.configure_rails_initialization" do |app|
      Rack::MiniProfilerRails.initialize!(app)
    end

    # TODO: Implement something better here
    # config.after_initialize do
    #
    #   class ::ActionView::Helpers::AssetTagHelper::JavascriptIncludeTag
    #     alias_method :asset_tag_orig, :asset_tag
    #     def asset_tag(source,options)
    #       current = Rack::MiniProfiler.current
    #       return asset_tag_orig(source,options) unless current
    #       wrapped = ""
    #       unless current.mpt_init
    #         current.mpt_init = true
    #         wrapped << Rack::MiniProfiler::ClientTimerStruct.init_instrumentation
    #       end
    #       name = source.split('/')[-1]
    #       wrapped << Rack::MiniProfiler::ClientTimerStruct.instrument(name, asset_tag_orig(source,options)).html_safe
    #       wrapped
    #     end
    #   end

    #   class ::ActionView::Helpers::AssetTagHelper::StylesheetIncludeTag
    #     alias_method :asset_tag_orig, :asset_tag
    #     def asset_tag(source,options)
    #       current = Rack::MiniProfiler.current
    #       return asset_tag_orig(source,options) unless current
    #       wrapped = ""
    #       unless current.mpt_init
    #         current.mpt_init = true
    #         wrapped << Rack::MiniProfiler::ClientTimerStruct.init_instrumentation
    #       end
    #       name = source.split('/')[-1]
    #       wrapped << Rack::MiniProfiler::ClientTimerStruct.instrument(name, asset_tag_orig(source,options)).html_safe
    #       wrapped
    #     end
    #   end

    # end

  end
end
