if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3
  ::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "executing action #{action}"}
end
