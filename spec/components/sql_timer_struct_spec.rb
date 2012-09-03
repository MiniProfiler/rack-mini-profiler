require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::SqlTimerStruct do

  describe 'valid sql timer' do
    before do
      @sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
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


  
  describe 'backtrace' do
    it 'has a snippet' do
      sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
      sql['StackTraceSnippet'].should_not be nil
    end

    it 'includes rspec in the trace (default is no filter)' do
      sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
      sql['StackTraceSnippet'].should match /rspec/
    end

    it "doesn't include rspec if we filter for only app" do
      Rack::MiniProfiler.config.backtrace_includes = [/\/app/]
      sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
      sql['StackTraceSnippet'].should_not match /rspec/
    end

    it "includes rspec if we filter for it" do
      Rack::MiniProfiler.config.backtrace_includes = [/\/(app|rspec)/]
      sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
      sql['StackTraceSnippet'].should match /rspec/
    end

    it "ingores rspec if we specifically ignore it" do  
      Rack::MiniProfiler.config.backtrace_ignores = [/\/rspec/]
      sql = Rack::MiniProfiler::SqlTimerStruct.new("SELECT * FROM users", 200, Rack::MiniProfiler::PageTimerStruct.new({}), nil)
      sql['StackTraceSnippet'].should_not match /rspec/
    end


  end

end
