require 'spec_helper'

describe Rack::MiniProfiler::TimerStruct::Page do

  before do
    @page = Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  it 'has an Id' do
    @page[:id].should_not be_nil
  end

  it 'has a Root' do
    @page[:root].should_not be_nil
  end

  describe 'to_json' do
    before do
      @json = @page.to_json
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a Started element' do
      @deserialized['started'].should_not be_nil
    end

    it 'has a DurationMilliseconds element' do
      @deserialized['duration_milliseconds'].should_not be_nil
    end
  end

end
