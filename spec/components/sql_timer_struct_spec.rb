require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::SqlTimerStruct do

  before do
    @sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}))
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
  

end