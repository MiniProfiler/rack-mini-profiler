require 'spec_helper'
describe Rack::MiniProfiler::FileStore do

  context 'page struct' do

    before do
      tmp = File.expand_path(__FILE__ + "/../../../tmp")
      Dir::mkdir(tmp) unless File.exists?(tmp)
      @store = Rack::MiniProfiler::FileStore.new(:path => tmp)
    end

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
        page_struct[:id] = "XYZ"
        page_struct[:random] = "random"
        @store.save(page_struct)
        page_struct = @store.load('XYZ')
        page_struct[:random].should == "random"
        page_struct[:id].should == "XYZ"
      end

      it 'can list unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.get_unviewed_ids('a').sort.to_a.should == ['XYZ', 'ABC'].sort.to_a
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
