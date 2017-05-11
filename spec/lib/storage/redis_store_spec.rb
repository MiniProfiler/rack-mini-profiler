require 'spec_helper'

describe Rack::MiniProfiler::RedisStore do
  let(:store) { Rack::MiniProfiler::RedisStore.new(:db=>2) }

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
        underlying_client = store.send(:redis).client

        underlying_client.db.should == 2
      end
    end
  end

  context 'passing in a Redis connection' do
    describe 'connection' do
      it 'uses the passed in object rather than creating a new one' do
        connection = double("redis-connection")
        store = Rack::MiniProfiler::RedisStore.new(:connection => connection)

        connection.should_receive(:get)
        Redis.should_not_receive(:new)
        store.load("XYZ")
      end
    end
  end

  context 'page struct' do
    describe 'storage' do
      let(:page_structs) { [Rack::MiniProfiler::TimerStruct::Page.new({}),
                            Rack::MiniProfiler::TimerStruct::Page.new({})] }

      it 'can store a PageStruct and retrieve it' do
        page_structs.first[:id] = "XYZ"
        page_structs.first[:random] = "random"
        store.save(page_structs.first)

        page_struct = store.load(page_structs.first[:id])

        page_struct[:random].should eq("random")
        page_struct[:id].should eq("XYZ")
      end

      it 'can list unviewed items for a user' do
        page_structs.each do |page_struct|
          store.set_unviewed('a', page_struct[:id])
          store.save(page_struct)
        end

        store.get_unviewed_ids('a').should =~ page_structs.map { |page_struct| page_struct[:id] }
      end

      it 'can set all unviewed items for a user' do
        page_structs.each { |page_struct| store.save(page_struct) }
        store.get_unviewed_ids('a').should be_empty

        store.set_all_unviewed('a', page_structs.map { |page_struct| page_struct[:id] })

        store.get_unviewed_ids('a').should =~ page_structs.map { |page_struct| page_struct[:id] }
      end

      it 'can set an item to viewed once it is unviewed' do
        page_structs.each do |page_struct|
          store.set_unviewed('a', page_struct[:id])
          store.save(page_struct)
        end

        store.set_viewed('a', page_structs.first[:id])
        store.get_unviewed_ids('a').should =~ page_structs.drop(1).map{ |page_struct| page_struct[:id] }
      end
    end
  end

  describe '#get_unviewed_ids' do
    let(:expired_record_key) { 'xyz098' }
    let(:existing_struct) { Rack::MiniProfiler::TimerStruct::Page.new({}) }

    it 'should only return ids for keys that exist' do
      user = 1234
      expired_record_id = 'xyz098'

      # Simulate a valid record
      store.set_unviewed(user, existing_struct[:id])
      store.save(existing_struct)

      # Simluate a record that may have expired, but could remain in the list of ids
      store.set_unviewed(user, expired_record_id)

      # Only the PageStruct that still exists should be returned
      store.get_unviewed_ids(user).should eq([existing_struct[:id]])
    end
  end

  describe 'allowed_tokens' do
    it 'should return tokens' do
      store.flush_tokens

      tokens = store.allowed_tokens
      tokens.length.should == 1

      store.simulate_expire

      new_tokens = store.allowed_tokens

      new_tokens.length.should == 2
      (new_tokens - tokens).length.should == 1
    end
  end

  describe 'diagnostics' do
    it "returns useful info" do
      res = store.diagnostics('a')
      expected = "Redis prefix: MPRedisStore\nRedis location: 127.0.0.1:6379 db: 2\nunviewed_ids: []\n"
      expect(res).to eq(expected)
    end
  end
end
