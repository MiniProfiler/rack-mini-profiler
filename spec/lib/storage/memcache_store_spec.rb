require 'spec_helper'
describe Rack::MiniProfiler::MemcacheStore do

  context 'page struct' do

    before do
      @store = Rack::MiniProfiler::MemcacheStore.new
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
        @store.get_unviewed_ids('a').length.should == 2
        @store.get_unviewed_ids('a').include?('XYZ').should be_true
        @store.get_unviewed_ids('a').include?('ABC').should be_true
      end

      it 'can set all unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_all_unviewed('a', %w(111 222))
        @store.get_unviewed_ids('a').should == ['111', '222']
        @store.set_all_unviewed('a', [])
      end

      it 'can set an item to viewed once it is unviewed' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_viewed('a', 'XYZ')
        @store.get_unviewed_ids('a').should == ['ABC']
      end

    end

  end


  describe 'allowed_tokens' do
    before do
      @store = Rack::MiniProfiler::MemcacheStore.new
    end

    it 'should return tokens' do

      @store.flush_tokens

      tokens = @store.allowed_tokens
      tokens.length.should == 1
      tokens.should == @store.allowed_tokens

      Time.travel(Time.now + 1) do
        new_tokens = @store.allowed_tokens
        new_tokens.length.should == 1
        new_tokens.should == tokens
      end

      Time.travel(Time.now + Rack::MiniProfiler::AbstractStore::MAX_TOKEN_AGE + 1) do
        new_tokens = @store.allowed_tokens
        new_tokens.length.should == 2
        (new_tokens - tokens).length.should == 1
      end
    end
  end

  context 'passing in a Memcache client' do
    describe 'client' do
      it 'uses the passed in object rather than creating a new one' do
        client = double("memcache-client")
        store = Rack::MiniProfiler::MemcacheStore.new(:client => client)

        client.should_receive(:get)
        Dalli::Client.should_not_receive(:new)
        store.load("XYZ")
      end
    end
  end

end
