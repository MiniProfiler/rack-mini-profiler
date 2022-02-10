# frozen_string_literal: true

require 'digest'

module Rack
  class MiniProfiler
    class RedisStore < AbstractStore

      attr_reader :prefix

      EXPIRES_IN_SECONDS = 60 * 60 * 24

      def initialize(args = nil)
        @args               = args || {}
        @prefix             = @args.delete(:prefix) || 'MPRedisStore'
        @redis_connection   = @args.delete(:connection)
        @expires_in_seconds = @args.delete(:expires_in) || EXPIRES_IN_SECONDS
      end

      def save(page_struct)
        redis.setex prefixed_id(page_struct[:id]), @expires_in_seconds, Marshal::dump(page_struct)
      end

      def load(id)
        key = prefixed_id(id)
        raw = redis.get key
        begin
          # rubocop:disable Security/MarshalLoad
          Marshal.load(raw) if raw
          # rubocop:enable Security/MarshalLoad
        rescue
          # bad format, junk old data
          redis.del key
          nil
        end
      end

      def set_unviewed(user, id)
        key = user_key(user)
        if redis.call([:exists, prefixed_id(id)]) == 1
          expire_at = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i + redis.ttl(prefixed_id(id))
          redis.zadd(key, expire_at, id)
        end
        redis.expire(key, @expires_in_seconds)
      end

      def set_all_unviewed(user, ids)
        key = user_key(user)
        redis.del(key)
        ids.each do |id|
          if redis.call([:exists, prefixed_id(id)]) == 1
            expire_at = Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i + redis.ttl(prefixed_id(id))
            redis.zadd(key, expire_at, id)
          end
        end
        redis.expire(key, @expires_in_seconds)
      end

      def set_viewed(user, id)
        redis.zrem(user_key(user), id)
      end

      # Remove expired ids from the unviewed sorted set and return the remaining ids
      def get_unviewed_ids(user)
        key = user_key(user)
        redis.zremrangebyscore(key, '-inf', Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i)
        redis.zrevrangebyscore(key, '+inf', '-inf')
      end

      def diagnostics(user)
        client = (redis.respond_to? :_client) ? redis._client : redis.client
"Redis prefix: #{@prefix}
Redis location: #{client.host}:#{client.port} db: #{client.db}
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
        redis.setex "#{@prefix}-key1_old", timeout * 2, key1

        [key1, key2].compact
      end

      COUNTER_LUA = <<~LUA
        if redis.call("INCR", KEYS[1]) % ARGV[1] == 0 then
          redis.call("DEL", KEYS[1])
          return 1
        else
          return 0
        end
      LUA

      COUNTER_LUA_SHA = Digest::SHA1.hexdigest(COUNTER_LUA)

      def should_take_snapshot?(period)
        1 == cached_redis_eval(
          COUNTER_LUA,
          COUNTER_LUA_SHA,
          reraise: false,
          keys: [snapshot_counter_key()],
          argv: [period]
        )
      end

      def push_snapshot(page_struct, config)
        zset_key = snapshot_zset_key()
        hash_key = snapshot_hash_key()

        id = page_struct[:id]
        score = page_struct.duration_ms
        limit = config.snapshots_limit
        bytes = Marshal.dump(page_struct)

        lua = <<~LUA
          local zset_key = KEYS[1]
          local hash_key = KEYS[2]
          local id = ARGV[1]
          local score = tonumber(ARGV[2])
          local bytes = ARGV[3]
          local limit = tonumber(ARGV[4])
          redis.call("ZADD", zset_key, score, id)
          redis.call("HSET", hash_key, id, bytes)
          if redis.call("ZCARD", zset_key) > limit then
            local lowest_snapshot_id = redis.call("ZRANGE", zset_key, 0, 0)[1]
            redis.call("ZREM", zset_key, lowest_snapshot_id)
            redis.call("HDEL", hash_key, lowest_snapshot_id)
          end
        LUA
        redis.eval(
          lua,
          keys: [zset_key, hash_key],
          argv: [id, score, bytes, limit]
        )
      end

      def fetch_snapshots(batch_size: 200, &blk)
        zset_key = snapshot_zset_key()
        hash_key = snapshot_hash_key()
        iteration = 0
        corrupt_snapshots = []
        while true
          ids = redis.zrange(
            zset_key,
            batch_size * iteration,
            batch_size * iteration + batch_size - 1
          )
          break if ids.size == 0
          batch = redis.mapped_hmget(hash_key, *ids).to_a
          batch.map! do |id, bytes|
            begin
              # rubocop:disable Security/MarshalLoad
              Marshal.load(bytes)
              # rubocop:enable Security/MarshalLoad
            rescue
              corrupt_snapshots << id
              nil
            end
          end
          batch.compact!
          blk.call(batch) if batch.size != 0
          break if ids.size < batch_size
          iteration += 1
        end
        if corrupt_snapshots.size > 0
          redis.pipelined do |pipeline|
            pipeline.zrem(zset_key, corrupt_snapshots)
            pipeline.hdel(hash_key, corrupt_snapshots)
          end
        end
      end

      def load_snapshot(id)
        hash_key = snapshot_hash_key()
        bytes = redis.hget(hash_key, id)
        begin
          # rubocop:disable Security/MarshalLoad
          Marshal.load(bytes)
          # rubocop:enable Security/MarshalLoad
        rescue
          redis.pipelined do |pipeline|
            pipeline.zrem(snapshot_zset_key(), id)
            pipeline.hdel(hash_key, id)
          end
          nil
        end
      end

      private

      def user_key(user)
        "#{@prefix}-#{user}-v1"
      end

      def prefixed_id(id)
        "#{@prefix}#{id}"
      end

      def redis
        @redis_connection ||= begin
          require 'redis' unless defined? Redis
          Redis.new(@args)
        end
      end

      def snapshot_counter_key
        @snapshot_counter_key ||= "#{@prefix}-mini-profiler-snapshots-counter"
      end

      def snapshot_zset_key
        @snapshot_zset_key ||= "#{@prefix}-mini-profiler-snapshots-zset"
      end

      def snapshot_hash_key
        @snapshot_hash_key ||= "#{@prefix}-mini-profiler-snapshots-hash"
      end

      def cached_redis_eval(script, script_sha, reraise: true, argv: [], keys: [])
        begin
          redis.evalsha(script_sha, argv: argv, keys: keys)
        rescue ::Redis::CommandError => e
          if e.message.start_with?('NOSCRIPT')
            redis.eval(script, argv: argv, keys: keys)
          else
            raise e if reraise
          end
        end
      end

      # only used in tests
      def wipe_snapshots_data
        redis.del(
          snapshot_counter_key(),
          snapshot_zset_key(),
          snapshot_hash_key(),
        )
      end
    end
  end
end
