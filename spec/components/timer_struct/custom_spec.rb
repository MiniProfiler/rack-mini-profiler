require 'spec_helper'

describe Rack::MiniProfiler::TimerStruct::Custom do
  before do
    @name = 'cool request'
    @page    = Rack::MiniProfiler::TimerStruct::Page.new({})
    @request = Rack::MiniProfiler::TimerStruct::Request.createRoot(@name, @page)
    @custom  = Rack::MiniProfiler::TimerStruct::Custom.new('a', 0.2, @page, @request)
  end

  it 'has an type' do
    @custom['Type'].should_not be_nil
  end

  it 'has a dur milliseconds' do
    @custom['DurationMilliseconds'].should_not be_nil
  end

  it 'has a StartMilliseconds' do
    @custom['StartMilliseconds'].should_not be_nil
  end

  describe 'to_json' do
    before do
      @json = @custom.to_json
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a DurationMilliseconds element' do
      @deserialized['DurationMilliseconds'].should_not be_nil
    end
  end

end
