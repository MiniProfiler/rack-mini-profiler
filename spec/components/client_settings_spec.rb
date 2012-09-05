require 'spec_helper'
require 'mini_profiler/client_settings'
require 'uri'
require 'rack'

describe Rack::MiniProfiler::ClientSettings do

  describe "with settings" do
    before do
      settings = URI.encode_www_form_component("dp=t,bt=1")
      @settings = Rack::MiniProfiler::ClientSettings.new({"HTTP_COOKIE" => "__profilin=#{settings};" })
    end

    it 'has the cookies' do
      @settings.has_cookie?.should be_true 
    end

    it 'has profiling disabled' do 
      @settings.disable_profiling?.should be_true
    end

    it 'has backtrace set to full' do 
      @settings.backtrace_full?.should be_true
    end

    it 'should not write cookie changes if no change' do 
      hash = {}
      @settings.write!(hash)
      hash.should == {}
    end

    it 'should correctly write cookie changes if changed' do
      @settings.disable_profiling = false
      hash = {}
      @settings.write!(hash)
      hash.should_not == {}
    end
  end

  it "should not have settings by default" do 
    Rack::MiniProfiler::ClientSettings.new({}).has_cookie?.should == false
  end


end
