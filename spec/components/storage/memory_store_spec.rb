require 'spec_helper'

describe Rack::MiniProfiler::MemoryStore do

  context 'page struct' do

    before do
      @store = Rack::MiniProfiler::MemoryStore.new
    end

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = {'Id' => "XYZ", 'Random' => "random"}
        @store.save(page_struct)
        page_struct = @store.load("XYZ")
        page_struct['Id'].should == "XYZ"
        page_struct['Random'].should == "random"
      end

      it 'can list unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.get_unviewed_ids('a').should == ['XYZ', 'ABC']
      end

      it 'can set an item to viewed once it is unviewed' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_viewed('a', 'XYZ')
        @store.get_unviewed_ids('a').should == ['ABC']
      end

    end

  end


  context 'cleanup_cache' do
    before do
      @fast_expiring_store = Rack::MiniProfiler::MemoryStore.new(expires_in: 1)
    end

    it "cleans up expired values" do
      old_page_struct = {'Id' => "XYZ", 'Random' => "random", 'Started' => ((Time.now.to_f - 2) * 1000).to_i }
      @fast_expiring_store.save(old_page_struct)
      old_page_struct = @fast_expiring_store.load("XYZ")
      old_page_struct['Id'].should == "XYZ"
      @fast_expiring_store.cleanup_cache
      page_struct = @fast_expiring_store.load("XYZ")
      expect(page_struct).to eq(nil)
    end
  end

end
