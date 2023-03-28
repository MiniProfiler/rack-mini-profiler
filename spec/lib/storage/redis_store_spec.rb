# frozen_string_literal: true

describe Rack::MiniProfiler::RedisStore do
  let(:config) { Rack::MiniProfiler::Config.default }
  let(:page_class) { Rack::MiniProfiler::TimerStruct::Page }
  let(:store) { Rack::MiniProfiler::RedisStore.new(db: 2, expires_in: 4) }

  before do
    store.send(:redis).flushdb
  end

  let(:page_structs) { [Rack::MiniProfiler::TimerStruct::Page.new({}),
                        Rack::MiniProfiler::TimerStruct::Page.new({})] }

  include_examples "snapshots storage", Rack::MiniProfiler::RedisStore.new(db: 2, expires_in: 4)

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
      expected = "Redis prefix: MPRedisStore\nRedis location: localhost:6379 db: 2\nunviewed_ids: []\n"
      expect(res).to eq(expected)
    end
  end

  describe '#fetch_snapshots_group' do
    # testing implementation details; feel free to remove
    # if/when it becomes irrelevant
    it 'deletes corrupt/invalid snapshots' do
      config.max_snapshots_per_group = 3
      page1 = page_class.new({}).tap { |s| s[:root].record_time(1.0) }
      store.push_snapshot(page1, 'group1', config)

      page2 = page_class.new({}).tap { |s| s[:root].record_time(2.0) }
      store.push_snapshot(page2, 'group1', config)

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(
        page1[:id],
        page2[:id]
      )
      overview = store.snapshots_overview
      expect(overview.size).to eq(1)
      expect(overview.first[:worst_score]).to eq(2.0)

      # reach to redis and shuffle the data so it becomes corrupted and
      # snapshot fails to load
      redis = store.send(:redis)
      redis.hset(
        store.send(:group_snapshot_hash_key, 'group1'),
        page2[:id],
        redis.hget(
          store.send(:group_snapshot_hash_key, 'group1'),
          page2[:id]
        ).b.split('').shuffle.join
      )

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(page1[:id])

      overview = store.snapshots_overview
      expect(overview.size).to eq(1)
      expect(overview.first[:worst_score]).to eq(1.0)

      redis.hset(
        store.send(:group_snapshot_hash_key, 'group1'),
        page1[:id],
        redis.hget(
          store.send(:group_snapshot_hash_key, 'group1'),
          page1[:id]
        ).b.split('').shuffle.join
      )

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.size).to eq(0)

      overview = store.snapshots_overview
      expect(overview.size).to eq(0)
      expect(redis.hgetall(store.send(:group_snapshot_hash_key, 'group1'))).to eq({})
      expect(redis.zrange(store.send(:group_snapshot_zset_key, 'group1'), 0, -1)).to eq([])
    end
  end

  describe '#load_snapshot' do
    # testing some implementation details feel free to remove if this
    # becomes irrelevant
    it 'deletes corrupt/invalid snapshots' do
      store.send(:wipe_snapshots_data)

      corrupt_page = Rack::MiniProfiler::TimerStruct::Page.new({})
      corrupt_page[:root].record_time(100)
      store.push_snapshot(corrupt_page, 'group1', Rack::MiniProfiler::Config.default)

      redis = store.send(:redis)
      # reach to redis and shuffle the data so it becomes corrupted
      # and snapshot fails to load
      redis.hset(
        store.send(:group_snapshot_hash_key, 'group1'),
        corrupt_page[:id],
        redis.hget(
          store.send(:group_snapshot_hash_key, 'group1'),
          corrupt_page[:id]
        ).b.split('').shuffle.join
      )

      loaded = store.load_snapshot(corrupt_page[:id], 'group1')
      expect(loaded).to eq(nil)
      overview = store.snapshots_overview
      expect(overview.size).to eq(0)
      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.size).to eq(0)
      expect(redis.hgetall(store.send(:group_snapshot_hash_key, 'group1'))).to eq({})
      expect(redis.zrange(store.send(:group_snapshot_zset_key, 'group1'), 0, -1)).to eq([])
    end
  end
end
