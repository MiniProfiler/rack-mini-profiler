module Rack
  class MiniProfiler
    class RedisStore < AbstractStore

      attr_reader :prefix

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

      def set_all_unviewed(user, ids)
        key = "#{@prefix}-#{user}-v"
        redis.del key
        ids.each { |id| redis.sadd(key, id) }
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

      def flush_tokens
        redis.del("#{@prefix}-key1", "#{@prefix}-key1_old", "#{@prefix}-key2")
      end

      # Only used for testing
      def simulate_expire
        redis.del("#{@prefix}-key1")
      end

      def allowed_tokens
        key1, key1_old, key2 = redis.mget("#{@prefix}-key1", "#{@prefix}-key1_old", "#{@prefix}-key2")

        if key1 && (key1.length == 32)
          return [key1, key2].compact
        end

        timeout = Rack::MiniProfiler::AbstractStore::MAX_TOKEN_AGE

        # TODO  this could be moved to lua to correct a concurrency flaw
        # it is not critical cause worse case some requests will miss profiling info

        # no key so go ahead and set it
        key1 = SecureRandom.hex

        if key1_old && (key1_old.length == 32)
          key2 = key1_old
          redis.setex "#{@prefix}-key2", timeout, key2
        else
          key2 = nil
        end

        redis.setex "#{@prefix}-key1", timeout, key1
        redis.setex "#{@prefix}-key1_old", timeout*2, key1

        [key1, key2].compact
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
