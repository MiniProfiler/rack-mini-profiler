require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::SqlTimerStruct do

  before do
    @sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageStruct.new({}))
  end

  it 'allows us to set any attribute we want' do
    @sql['Hello'] = 'World'
    @sql['Hello'].should == 'World'
  end

  it 'has an ExecuteType' do
    @sql['ExecuteType'].should_not be_nil
  end

  it 'has a FormattedCommandString' do
    @sql['FormattedCommandString'].should_not be_nil
  end

  it 'has a StackTraceSnippet' do
    @sql['StackTraceSnippet'].should_not be_nil
  end  

  it 'has a StartMilliseconds' do
    @sql['StartMilliseconds'].should_not be_nil
  end   

  it 'has a DurationMilliseconds' do
    @sql['DurationMilliseconds'].should_not be_nil
  end 

  it 'has a IsDuplicate' do
    @sql['IsDuplicate'].should_not be_nil
  end   

  it 'allows us to set an attribute' do
    @sql['Hello'] = 'World'
    @sql['Hello'].should == 'World'
  end

  describe 'to_json' do
    before do
      @json = @sql.to_json
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

      it 'has a ExecuteType element' do
        @deserialized['ExecuteType'].should_not be_nil
      end
    end

  end
  

end