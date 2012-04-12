require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::PageTimerStruct do

  before do
    @page = Rack::MiniProfiler::PageTimerStruct.new({})
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
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a Started element' do
      @deserialized['Started'].should_not be_nil
    end

    it 'has a DurationMilliseconds element' do
      @deserialized['DurationMilliseconds'].should_not be_nil
    end
  end
  
end
