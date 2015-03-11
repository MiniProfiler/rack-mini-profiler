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

      it 'can set an item to viewed once it is unviewed' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_viewed('a', 'XYZ')
        @store.get_unviewed_ids('a').should == ['ABC']
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
