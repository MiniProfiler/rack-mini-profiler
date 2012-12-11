module Rack
  class MiniProfiler
    class RedisStore < AbstractStore

      EXPIRE_SECONDS = 60 * 60 * 24
     
      def initialize(args)
        @args = args || {}
        @prefix = @args.delete(:prefix) || 'MPRedisStore'
        @redis_connection = @args.delete(:connection)
      end

      def save(page_struct)
        redis.setex "#{@prefix}#{page_struct['Id']}", EXPIRE_SECONDS, Marshal::dump(page_struct) 
      end

      def load(id)
        raw = redis.get "#{@prefix}#{id}"
        if raw
          Marshal::load raw
        end
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
        return @redis_connection if @redis_connection
        require 'redis' unless defined? Redis
        Redis.new @args
      end

    end
  end
end
