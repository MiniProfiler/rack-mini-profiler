require 'spec_helper'

describe Rack::MiniProfiler::RedisStore do

  context 'establishing a connection to something other than the default' do
    before do
      @store = Rack::MiniProfiler::RedisStore.new(:db=>2)
    end

    describe "connection" do
      it 'can still store the resulting value' do
        page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
        page_struct[:id] = "XYZ"
        page_struct[:random] = "random"
        @store.save(page_struct)
      end

      it 'uses the correct db' do
        # redis is private, and possibly should remain so?
        underlying_client = @store.send(:redis).client

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

    before do
      @store = Rack::MiniProfiler::RedisStore.new(nil)
    end

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
        page_struct[:id] = "XYZ"
        page_struct[:random] = "random"
        @store.save(page_struct)
        page_struct = @store.load("XYZ")
        page_struct[:random].should == "random"
        page_struct[:id].should == "XYZ"
      end

      it 'can list unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.get_unviewed_ids('a').should =~ ['XYZ', 'ABC']
      end

      it 'can set an item to viewed once it is unviewed' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_viewed('a', 'XYZ')
        @store.get_unviewed_ids('a').should == ['ABC']
      end

    end

  end


  describe 'diagnostics' do
    before do
      @store = Rack::MiniProfiler::RedisStore.new(:db=>2)
    end
    it "returns useful info" do
      res = @store.diagnostics('a')
      expected = "Redis prefix: MPRedisStore\nRedis location: 127.0.0.1:6379 db: 2\nunviewed_ids: []\n"
      expect(res).to eq(expected)
    end
  end

end
