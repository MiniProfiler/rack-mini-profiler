# frozen_string_literal: true

describe Rack::MiniProfiler::RedisStore do
  let(:store) { Rack::MiniProfiler::RedisStore.new(db: 2, expires_in: 4) }
  let(:page_structs) { [Rack::MiniProfiler::TimerStruct::Page.new({}),
                        Rack::MiniProfiler::TimerStruct::Page.new({})] }

  before do
    store.send(:redis).flushdb
  end

  context 'establishing a connection to something other than the default' do
    describe "connection" do
      it 'can still store the resulting value' do
        page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
        page_struct[:id] = "XYZ"
        page_struct[:random] = "random"
        store.save(page_struct)
      end

      it 'uses the correct db' do
        # redis is private, and possibly should remain so?
        redis = store.send(:redis)
        client = redis.respond_to?(:_client) ? redis._client : redis.client
        expect(client.db).to eq(2)
      end
    end
  end

  context 'passing in a Redis connection' do
    describe 'connection' do
      it 'uses the passed in object rather than creating a new one' do
        connection = instance_double("redis-connection")
        store = Rack::MiniProfiler::RedisStore.new(connection: connection)

        expect(connection).to receive(:get)
        expect(Redis).not_to receive(:new)
        store.load("XYZ")
      end
    end
  end

  context 'page struct' do
    describe 'storage' do
      it 'can store a PageStruct and retrieve it' do
        page_structs.first[:id] = "XYZ"
        page_structs.first[:random] = "random"
        store.save(page_structs.first)

        page_struct = store.load(page_structs.first[:id])

        expect(page_struct[:random]).to eq("random")
        expect(page_struct[:id]).to eq("XYZ")
      end

      it 'can list unviewed items for a user' do
        page_structs.each do |page_struct|
          store.save(page_struct)
          store.set_unviewed('a', page_struct[:id])
        end

        expect(store.get_unviewed_ids('a')).to match_array(page_structs.map { |page_struct| page_struct[:id] })
      end

      it 'can set all unviewed items for a user' do
        page_structs.each { |page_struct| store.save(page_struct) }
        expect(store.get_unviewed_ids('a')).to be_empty

        store.set_all_unviewed('a', page_structs.map { |page_struct| page_struct[:id] })

        expect(store.get_unviewed_ids('a')).to match_array(page_structs.map { |page_struct| page_struct[:id] })
      end

      it 'can set an item to viewed once it is unviewed' do
        page_structs.each do |page_struct|
          store.save(page_struct)
          store.set_unviewed('a', page_struct[:id])
        end

        store.set_viewed('a', page_structs.first[:id])
        expect(store.get_unviewed_ids('a')).to match_array(page_structs.drop(1).map { |page_struct| page_struct[:id] })
      end
    end
  end

  describe '#get_unviewed_ids' do
    let(:expired_record_key) { 'xyz098' }
    let(:user) { 1234 }

    it 'should only return ids for keys that are not expired' do
      # Simulate a record which will expire
      store.save(page_structs.first)
      store.set_unviewed(user, page_structs.first[:id])

      # Store has an expiration of 4, so wait a bit before adding the second struct
      sleep(2)

      # Simulate adding a record before the first page struct expires
      store.save(page_structs.last)
      store.set_unviewed(user, page_structs.last[:id])

      # Let the first page struct expire
      sleep(2)

      # By now, the first struct should have expired and should no longer be returned
      expect(store.get_unviewed_ids(user)).to eq([page_structs.last[:id]])
    end
  end

  describe 'allowed_tokens' do
    it 'should return tokens' do
      store.flush_tokens

      tokens = store.allowed_tokens
      expect(tokens.length).to eq(1)
      store.simulate_expire

      new_tokens = store.allowed_tokens
      expect(new_tokens.length).to eq(2)
      expect((new_tokens - tokens).length).to eq(1)
    end
  end

  describe 'data resilience on upgrade' do

    before do
      store.send(:redis).sadd("MPRedisStore-bob-v", "test")
    end

    it "handles set_viewed" do
      store.set_viewed("bob", "x")
    end

    it "handles get_unviewed_ids" do
      store.get_unviewed_ids("bob")
    end

    it "handles set_unviewed" do
      page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
      page_struct[:id] = "XYZ"
      store.save(page_struct)

      store.set_unviewed("bob", "XYZ")
    end

  end

  describe 'diagnostics' do
    it "returns useful info" do
      res = store.diagnostics('a')
      expected = "Redis prefix: MPRedisStore\nRedis location: 127.0.0.1:6379 db: 2\nunviewed_ids: []\n"
      expect(res).to eq(expected)
    end
  end

  describe '#push_snapshot' do
    # testing implementation details here (specifically the LUA script
    # in the push_snapshot method). If you've changed the script and
    # these tests start failing, it probably makes sense to remove them
    # entirely.
    it 'keeps the worst snapshots and respects the config limit' do
      store.send(:wipe_snapshots_data)

      config = Rack::MiniProfiler::Config.default
      config.snapshots_limit = 3
      pstruct_class = Rack::MiniProfiler::TimerStruct::Page
      pstruct1 = pstruct_class.new({}).tap { |s| s[:root].record_time(30) }
      pstruct2 = pstruct_class.new({}).tap { |s| s[:root].record_time(20) }
      pstruct3 = pstruct_class.new({}).tap { |s| s[:root].record_time(40) }
      pstruct4 = pstruct_class.new({}).tap { |s| s[:root].record_time(10) }
      pstruct5 = pstruct_class.new({}).tap { |s| s[:root].record_time(50) }

      store.push_snapshot(pstruct1, config)
      store.push_snapshot(pstruct2, config)
      store.push_snapshot(pstruct3, config)
      store.push_snapshot(pstruct4, config)
      store.push_snapshot(pstruct5, config)

      redis = store.send(:redis)
      expect(redis.hkeys(store.send(:snapshot_hash_key))).to contain_exactly(
        pstruct1[:id],
        pstruct3[:id],
        pstruct5[:id]
      )
      expect(redis.zrange(store.send(:snapshot_zset_key), 0, -1)).to contain_exactly(
        pstruct1[:id],
        pstruct3[:id],
        pstruct5[:id]
      )
    end
  end

  describe '#fetch_snapshots' do
    # testing implementation details; feel free to remove
    # if/when it becomes irrelevant
    it 'deletes keys of corrupt/invalid snapshots' do
      store.send(:wipe_snapshots_data)

      page = Rack::MiniProfiler::TimerStruct::Page.new({})
      page[:root].record_time(400)
      store.push_snapshot(page, Rack::MiniProfiler::Config.default)

      corrupt_page = Rack::MiniProfiler::TimerStruct::Page.new({})
      corrupt_page[:root].record_time(100)
      store.push_snapshot(corrupt_page, Rack::MiniProfiler::Config.default)

      redis = store.send(:redis)
      # reach to redis and shuffle the data so it
      # becomes corrupted and snapshot fails to load
      redis.hset(
        store.send(:snapshot_hash_key),
        corrupt_page[:id],
        redis.hget(
          store.send(:snapshot_hash_key),
          corrupt_page[:id]
        ).b.split('').shuffle.join
      )

      calls = 0
      fetched_snapshots = []
      store.fetch_snapshots(batch_size: 1) do |snapshots|
        calls += 1
        fetched_snapshots.concat(snapshots)
      end
      expect(calls).to eq(1)
      expect(fetched_snapshots.size).to eq(1)
      expect(fetched_snapshots.first[:id]).to eq(page[:id])
      expect(redis.hkeys(store.send(:snapshot_hash_key))).to eq([page[:id]])
      expect(redis.zrange(store.send(:snapshot_zset_key), 0, -1)).to eq([page[:id]])
    end
  end

  describe '#load_snapshot' do
    # testing some implementation details
    # feel free to remove if this becomes
    # irrelevant
    it 'deletes corrupt/invalid snapshots' do
      store.send(:wipe_snapshots_data)

      corrupt_page = Rack::MiniProfiler::TimerStruct::Page.new({})
      corrupt_page[:root].record_time(100)
      store.push_snapshot(corrupt_page, Rack::MiniProfiler::Config.default)

      redis = store.send(:redis)
      # reach to redis and shuffle the data so it
      # becomes corrupted and snapshot fails to load
      redis.hset(
        store.send(:snapshot_hash_key),
        corrupt_page[:id],
        redis.hget(
          store.send(:snapshot_hash_key),
          corrupt_page[:id]
        ).b.split('').shuffle.join
      )

      loaded = store.load_snapshot(corrupt_page[:id])
      expect(loaded).to eq(nil)
      expect(redis.hkeys(store.send(:snapshot_hash_key))).to eq([])
      expect(redis.zrange(store.send(:snapshot_zset_key), 0, -1)).to eq([])
    end
  end

  include_examples "snapshots storage", Rack::MiniProfiler::RedisStore.new(db: 2, expires_in: 4)
end
