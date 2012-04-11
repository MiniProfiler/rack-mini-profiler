require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::PageStruct do

  before do
    @page = Rack::MiniProfiler::PageStruct.new({})
  end

  it 'allows us to set any attribute we want' do
    @page['Hello'] = 'World'
    @page['Hello'].should == 'World'
  end

  it 'has an Id' do
    @page['Id'].should_not be_nil
  end

  it 'has a Root' do
    @page['Root'].should_not be_nil
  end

  describe 'to_json' do
    before do
      @json = @page.to_json
    end

    it 'produces JSON' do
      @json.should_not be_nil
    end  

    describe 'deserialized' do
      before do
        @deserialized = ::JSON.parse(@json)
      end

      it 'produces a hash' do
        @deserialized.is_a?(Hash).should be_true
      end

      it 'has a Started element' do
        @deserialized['Started'].should_not be_nil
      end

      it 'has a DurationMilliseconds element' do
        @deserialized['DurationMilliseconds'].should_not be_nil
      end
    end

  end
  
end
