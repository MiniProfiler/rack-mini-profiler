require 'mini_profiler/profiler'
require 'patches/sql_patches'
require 'patches/net_patches'

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'mini_profiler_rails/railtie'
end
