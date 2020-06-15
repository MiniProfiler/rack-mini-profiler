# frozen_string_literal: true

describe Rack::MiniProfiler::TimerStruct::Custom do
  before do
    @name    = 'cool request'
    @page    = Rack::MiniProfiler::TimerStruct::Page.new({})
    @request = Rack::MiniProfiler::TimerStruct::Request.createRoot(@name, @page)
    @custom  = Rack::MiniProfiler::TimerStruct::Custom.new('a', 0.2, @page, @request)
  end

  it 'has an type' do
    expect(@custom[:type]).not_to be_nil
  end

  it 'has a dur milliseconds' do
    expect(@custom[:duration_milliseconds]).not_to be_nil
  end

  it 'has a start_milliseconds' do
    expect(@custom[:start_milliseconds]).not_to be_nil
  end

  describe 'to_json' do
    before do
      @json = @custom.to_json
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a DurationMilliseconds element' do
      expect(@deserialized['duration_milliseconds']).not_to be_nil
    end
  end

end
