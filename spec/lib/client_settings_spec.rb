require 'spec_helper'
require 'rack'

describe Rack::MiniProfiler::ClientSettings do

  describe "with settings" do
    before do
      @store = Rack::MiniProfiler::MemoryStore.new
      settings = URI.encode_www_form_component("dp=t,bt=1")
      @settings = Rack::MiniProfiler::ClientSettings.new(
        {"HTTP_COOKIE" => "__profilin=#{settings};" },
        @store,
        Time.now
      )
    end

    it 'has the cookies' do
      @settings.has_valid_cookie?.should be_true
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

    it 'writes auth token for authorized reqs' do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.authorize_request
      hash = {}
      @settings.write!(hash)
      hash["Set-Cookie"].should include(@store.allowed_tokens.join("|"))
    end

    it 'does nothing on short unauthed requests' do
      @store.should_not_receive(:allowed_tokens)
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.deauthorize_request
      hash = {}
      @settings.handle_cookie([200, hash, []])

      hash.should == {}
    end

    it 'discards on long unauthed requests' do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.deauthorize_request
      hash = {}
      Time.travel(Time.now + 1) do
        @settings.handle_cookie([200, hash, []])
      end

      hash["Set-Cookie"].should include("max-age=0")
    end
  end

  describe "without a cookie" do
    before do
      @store = Rack::MiniProfiler::MemoryStore.new
      @settings = Rack::MiniProfiler::ClientSettings.new({}, @store, Time.now)
    end

    it "should not have settings by default" do
      @settings.has_valid_cookie?.should == false
    end

    it "should not access storage" do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.deauthorize_request
      @store.should_not_receive(:allowed_tokens)
      @settings.has_valid_cookie?.should be_false
    end
  end

end
