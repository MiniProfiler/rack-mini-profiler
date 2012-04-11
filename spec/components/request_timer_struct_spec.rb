require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler::RequestTimerStruct do

  before do
    @name = 'cool request'
    @request = Rack::MiniProfiler::RequestTimerStruct.new(@name, Rack::MiniProfiler::PageStruct.new({}))
  end

  it 'has an Id' do
    @request['Id'].should_not be_nil
  end

  it 'has a Root' do
    @request['Name'].should == @name
  end

  # TODO: Write more specs

end
