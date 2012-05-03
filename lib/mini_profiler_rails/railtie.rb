module MiniProfilerRails
  class Railtie < ::Rails::Railtie

    initializer "rack_mini_profiler.configure_rails_initialization" do |app|

      # By default, only show the MiniProfiler in development mode
      Rack::MiniProfiler.configuration[:authorize_cb] = lambda {|env| Rails.env.development? }

      # Quiet the SQL stack traces
      Rack::MiniProfiler.configuration[:backtrace_remove] = Rails.root.to_s + "/"
      Rack::MiniProfiler.configuration[:backtrace_filter] =  /^\/?(app|config|lib|test)/

      # Install the Middleware
      app.middleware.insert_after 'Rack::ConditionalGet', 'Rack::MiniProfiler'

      # Attach to various Rails methods
      ::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "Executing action: #{action}"}
      ::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{@virtual_path}"}


    end

  end
end
