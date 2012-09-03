require 'spec_helper'
require 'mini_profiler/storage/abstract_store'
require 'mini_profiler/storage/memory_store'

describe Rack::MiniProfiler::MemoryStore do

  context 'page struct' do

    before do
      @store = Rack::MiniProfiler::MemoryStore.new nil
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

end
