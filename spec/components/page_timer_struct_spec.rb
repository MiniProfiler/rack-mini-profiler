require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::PageTimerStruct do

  before do
    @page = Rack::MiniProfiler::PageTimerStruct.new({})
  end

  it 'has an id' do
    @page[:id].should_not be_nil
  end

  it 'has a root' do
    @page[:root].should_not be_nil
  end

  describe 'to_json' do
    before do
      @json = @page.to_json
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a started element' do
      @deserialized['started'].should_not be_nil
    end

    it 'has a duration_milliseconds element' do
      @deserialized['duration_milliseconds'].should_not be_nil
    end
  end
  
end
