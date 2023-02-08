# frozen_string_literal: true


module Rack
  class MiniProfiler
    autoload(:AbstractStore, 'mini_profiler/storage/abstract_store')
    autoload(:MemcacheStore, 'mini_profiler/storage/memcache_store')
    autoload(:MemoryStore, 'mini_profiler/storage/memory_store')
    autoload(:RedisStore, 'mini_profiler/storage/redis_store')
    autoload(:FileStore, 'mini_profiler/storage/file_store')
  end
end
