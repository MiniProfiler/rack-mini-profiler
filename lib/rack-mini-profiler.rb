require File.expand_path('mini_profiler/profiler', File.dirname(__FILE__) )
require File.expand_path('patches/sql_patches', File.dirname(__FILE__) )

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3
  require File.expand_path('mini_profiler_rails/railtie', File.dirname(__FILE__) )
end


