module Rack
  class MiniProfiler
    #
    # You may pass in either standard Redis configuration or a ConnectionPool
    # instance directly:
    #
    # Rack::MiniProfiler.config.storage_options = { :pool => Sidekiq.redis_pool }
    # Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisPoolStore
    #
    class RedisPoolStore < AbstractStore
      attr_reader :redis

      EXPIRES_IN_SECONDS = 60 * 60 * 24

      def initialize(args = nil)
        require 'redis'
        require 'connection_pool'
        @args               = args || {}
        @prefix             = @args.delete(:prefix)     || 'MPRedisStore'
        @expires_in_seconds = @args.delete(:expires_in) || EXPIRES_IN_SECONDS
        @redis              = @args.delete(:pool)       || ConnectionPool.new { Redis.new(@args) }
      end

      def save(page_struct)
        redis.with {|c| c.setex "#{@prefix}#{page_struct[:id]}", @expires_in_seconds, Marshal::dump(page_struct) }
      end

      def load(id)
        raw = redis.with {|c| c.get "#{@prefix}#{id}" }
        Marshal::load(raw) if raw
      end

      def set_unviewed(user, id)
        redis.with {|c| c.sadd "#{@prefix}-#{user}-v", id }
      end

      def set_viewed(user, id)
        redis.with {|c| c.srem "#{@prefix}-#{user}-v", id }
      end

      def get_unviewed_ids(user)
        redis.with {|c| c.smembers "#{@prefix}-#{user}-v" }
      end

      def diagnostics(user)
        redis.with do |c|
"Redis prefix: #{@prefix}
Redis location: #{c.client.host}:#{c.client.port} db: #{c.client.db}
unviewed_ids: #{c.smembers "#{@prefix}-#{user}-v"}
"
        end
      end

    end
  end
end
