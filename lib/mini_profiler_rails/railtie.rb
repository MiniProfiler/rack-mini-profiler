module MiniProfilerRails
  class Railtie < ::Rails::Railtie

    initializer "rack_mini_profiler.configure_rails_initialization" do |app|

      # Install the Middleware
      app.middleware.use Rack::MiniProfiler

      # Attach to various Rails methods
      ::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "Executing action: #{action}"}
      ::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{@virtual_path}"}

    end
    
  end
end
