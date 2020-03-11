# frozen_string_literal: true

require 'json'
require 'timeout'
require 'thread'
require 'securerandom'

require 'mini_profiler/version'
require 'mini_profiler/asset_version'

require 'mini_profiler/timer_struct/base'
require 'mini_profiler/timer_struct/page'
require 'mini_profiler/timer_struct/sql'
require 'mini_profiler/timer_struct/custom'
require 'mini_profiler/timer_struct/client'
require 'mini_profiler/timer_struct/request'

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
require 'patches/sql_patches'
require 'patches/net_patches'

if defined?(::Rails) && defined?(::Rails::VERSION) && ::Rails::VERSION::MAJOR.to_i >= 3
  require 'mini_profiler_rails/railtie'
end
