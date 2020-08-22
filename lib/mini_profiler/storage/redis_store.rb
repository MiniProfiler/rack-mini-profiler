# frozen_string_literal: true

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
          Marshal::load(raw) if raw
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

      def should_take_snapshot?(period)
        lua = <<~LUA
          if redis.call("INCR", KEYS[1]) % ARGV[1] == 0 then
            redis.call("DEL", KEYS[1])
            return 1
          else
            return 0
          end
        LUA

        1 == redis.eval(
          lua,
          keys: ["#{@prefix}-mini-profiler-snapshots-counter"],
          argv: [period]
        )
      end

      def push_snapshot(page_struct, group_name, config)
        id = page_struct[:id]
        score = page_struct.duration_ms
        group_zset_key = snapshot_zset_key(group_name)
        hash_key = snapshot_hash_key(group_name)
        zset_key = snapshot_groups_zset_key()
        page_struct_raw = Marshal::dump(page_struct)
        per_group_limit = config.max_snapshots_per_group
        groups_limit = config.max_snapshot_groups
        lua = <<~LUA
          local group_zset_key = KEYS[1]
          local hash_key = KEYS[2]
          local zset_key = KEYS[3]
          local score = tonumber(ARGV[1])
          local id = ARGV[2]
          local page_struct_raw = ARGV[3]
          local group_name = ARGV[4]
          local per_group_limit = tonumber(ARGV[5])
          local groups_limit = tonumber(ARGV[6])
          local prefix = ARGV[7]
          local current_group_score = redis.call("ZSCORE", zset_key, group_name)
          if current_group_score == false or score > tonumber(current_group_score) then
            redis.call("ZADD", zset_key, score, group_name)
          end
          local skip_snapshot = false
          if redis.call("ZCARD", zset_key) > groups_limit then
            local lowest_group = redis.call("ZRANGE", zset_key, 0, 0)[1]
            redis.call("ZREM", zset_key, lowest_group)
            skip_snapshot = lowest_group == group_name
            if not skip_snapshot then
              local lowest_group_zset_key = prefix .. "-mini-profiler-snapshots-zset-for-" .. lowest_group
              local lowest_group_hash_key = prefix .. "-mini-profiler-snapshots-hash-for-" .. lowest_group
              redis.call("DEL", lowest_group_zset_key)
              redis.call("DEL", lowest_group_hash_key)
            end
          end
          if not skip_snapshot then
            local skip_hash = false
            redis.call("ZADD", group_zset_key, score, id)
            if redis.call("ZCARD", group_zset_key) > per_group_limit then
              local lowest_snapshot_id = redis.call("ZRANGE", group_zset_key, 0, 0)[1]
              redis.call("ZREM", group_zset_key, lowest_snapshot_id)
              skip_hash = lowest_snapshot_id == id
              if not skip_hash then
                redis.call("HDEL", hash_key, lowest_snapshot_id)
              end
            end
            if not skip_hash then
              redis.call("HSET", hash_key, id, page_struct_raw)
            end
          end
        LUA
        redis.eval(
          lua,
          keys: [group_zset_key, hash_key, zset_key],
          argv: [score, id, page_struct_raw, group_name, per_group_limit, groups_limit, @prefix]
        )
      end

      def snapshots_overview
        data = []
        redis.zrange(snapshot_groups_zset_key(), 0, -1, withscores: true).each do |name, worst_score|
          data << { name: name, worst_score: worst_score }
        end
        data
      end

      def group_snapshots_list(group_name)
        data = []
        redis.zrange(snapshot_zset_key(group_name), 0, -1, withscores: true).each do |id, duration|
          hash = { id: id, duration: duration }
          page_struct = load_snapshot(id, group_name)
          next unless page_struct
          hash[:timestamp] = page_struct[:started_at]
          data << hash
        end
        data
      end

      def load_snapshot(id, group_name)
        key = snapshot_hash_key(group_name)
        raw = redis.hget(key, id)
        begin
          Marshal::load(raw) if raw
        rescue
          redis.hdel(key, id)
          redis.zrem(snapshot_zset_key(group_name), id)
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

      def snapshot_zset_key(group_name)
        # if you change the key, remember to chnage it the LUA
        # script in the push_snapshot method
        "#{@prefix}-mini-profiler-snapshots-zset-for-#{group_name}"
      end

      def snapshot_hash_key(group_name)
        # if you change the key, remember to chnage it the LUA
        # script in the push_snapshot method
        "#{@prefix}-mini-profiler-snapshots-hash-for-#{group_name}"
      end

      def snapshot_groups_zset_key
        "#{@prefix}-mini-profiler-snapshots-groups-zset"
      end

      # only used in tests
      def wipe_snapshots_data
        redis.keys.each do |key|
          redis.del(key) if key.include?("mini-profiler-snapshots")
        end
      end
    end
  end
end
