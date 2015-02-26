module Rack
  class MiniProfiler
    class RedisStore < AbstractStore

      EXPIRES_IN_SECONDS = 60 * 60 * 24

      def initialize(args = nil)
        @args               = args || {}
        @prefix             = @args.delete(:prefix)     || 'MPRedisStore'
        @redis_connection   = @args.delete(:connection)
        @expires_in_seconds = @args.delete(:expires_in) || EXPIRES_IN_SECONDS
      end

      def save(page_struct)
        redis.setex "#{@prefix}#{page_struct[:id]}", @expires_in_seconds, Marshal::dump(page_struct)
      end

      def load(id)
        key = "#{@prefix}#{id}"
        raw = redis.get key
        begin
          Marshal::load(raw) if raw
        rescue
          # bad format, junk old data
          redis.del key
          nil
        end
      end

      def set_unviewed(user, id)
        key = "#{@prefix}-#{user}-v"
        redis.sadd key, id
        redis.expire key, @expires_in_seconds
      end

      def set_viewed(user, id)
        redis.srem "#{@prefix}-#{user}-v", id
      end

      def get_unviewed_ids(user)
        redis.smembers "#{@prefix}-#{user}-v"
      end

      def diagnostics(user)
"Redis prefix: #{@prefix}
Redis location: #{redis.client.host}:#{redis.client.port} db: #{redis.client.db}
unviewed_ids: #{get_unviewed_ids(user)}
"
      end

      private

      def redis
        @redis_connection ||= begin
          require 'redis' unless defined? Redis
          Redis.new(@args)
        end
      end

    end
  end
end
