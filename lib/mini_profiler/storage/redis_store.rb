require 'redis'

module Rack
  class MiniProfiler
    class RedisStore < AbstractStore

      EXPIRE_SECONDS = 60 * 60 * 24
     
      def initialize(args = {})
        @prefix = args[:prefix] || 'MPRedisStore'
      end

      def save(page_struct)
        redis.setex "#{@prefix}#{page_struct['Id']}", EXPIRE_SECONDS, Marshal::dump(page_struct) 
      end

      def load(id)
        raw = redis.get "#{@prefix}#{id}"
        Marshal::load raw
      end

      def set_unviewed(user, id)
        redis.sadd "#{@prefix}-#{user}-v", id
      end

      def set_viewed(user, id)
        redis.srem "#{@prefix}-#{user}-v", id
      end

      def get_unviewed_ids(user)
        redis.smembers "#{@prefix}-#{user}-v"
      end

      private 

      def redis
        Redis.new '127.0.0.1'
      end

    end
  end
end
