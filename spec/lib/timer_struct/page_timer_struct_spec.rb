require 'spec_helper'

describe Rack::MiniProfiler::TimerStruct::Page do

  before do
    @page = Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  it 'has an Id' do
    expect(@page[:id]).not_to be_nil
  end

  it 'has a Root' do
    expect(@page[:root]).not_to be_nil
  end

  describe 'to_json' do
    before do
      @json = @page.to_json
      @deserialized = ::JSON.parse(@json)
    end

    it 'has a Started element' do
      expect(@deserialized['started']).not_to be_nil
    end

    it 'has a DurationMilliseconds element' do
      expect(@deserialized['duration_milliseconds']).not_to be_nil
    end
  end

end
