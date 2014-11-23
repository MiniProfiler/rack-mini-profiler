require 'json'
require 'timeout'
require 'thread'

require 'mini_profiler/version'
require 'mini_profiler/page_timer_struct'
require 'mini_profiler/sql_timer_struct'
require 'mini_profiler/custom_timer_struct'
require 'mini_profiler/client_timer_struct'
require 'mini_profiler/request_timer_struct'
require 'mini_profiler/storage/abstract_store'
require 'mini_profiler/storage/memcache_store'
require 'mini_profiler/storage/memory_store'
require 'mini_profiler/storage/redis_store'
require 'mini_profiler/storage/file_store'
require 'mini_profiler/config'
require 'mini_profiler/profiling_methods'
require 'mini_profiler/context'
require 'mini_profiler/client_settings'
require 'mini_profiler/gc_profiler'
require 'mini_profiler/profiler'
# TODO
# require 'mini_profiler/gc_profiler_ruby_head' if Gem::Version.new('2.1.0') <= Gem::Version.new(RUBY_VERSION)

require 'patches/sql_patches'
require 'patches/net_patches'

if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'mini_profiler_rails/railtie'
end
