module MiniProfilerRails
  class Railtie < ::Rails::Railtie

    initializer "rack_mini_profiler.configure_rails_initialization" do |app|
      c = Rack::MiniProfiler.config

      # By default, only show the MiniProfiler in development mode, in production allow profiling if post_authorize_cb is set
      c.pre_authorize_cb = lambda { |env|
        Rails.env.development? || Rails.env.production?  
      }

      if Rails.env.development?
        c.skip_paths ||= []
        c.skip_paths << "/assets/"
        c.skip_schema_queries = true
      end

      if Rails.env.production? 
        c.authorization_mode = :whitelist
      end

      # The file store is just so much less flaky
      tmp = Rails.root.to_s + "/tmp/miniprofiler"
      Dir::mkdir(tmp) unless File.exists?(tmp)

      c.storage_options = {:path => tmp}
      c.storage = Rack::MiniProfiler::FileStore

      # Quiet the SQL stack traces
      c.backtrace_remove = Rails.root.to_s + "/"
      c.backtrace_filter =  /^\/?(app|config|lib|test)/
      c.skip_schema_queries =  Rails.env != 'production'

      # Install the Middleware
      app.middleware.insert(0, Rack::MiniProfiler)

      # Attach to various Rails methods
      ::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "Executing action: #{action}"}
      ::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{@virtual_path}"}


    end

  end
end
