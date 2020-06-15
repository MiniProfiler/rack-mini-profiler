# frozen_string_literal: true

require 'rack'

describe Rack::MiniProfiler::ClientSettings do

  describe "with settings" do
    before do
      @store = Rack::MiniProfiler::MemoryStore.new
      settings = URI.encode_www_form_component("dp=t,bt=1")
      @settings = Rack::MiniProfiler::ClientSettings.new(
        { "HTTP_COOKIE" => "__profilin=#{settings};" },
        @store,
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      )
    end

    it 'has the cookies' do
      expect(@settings.has_valid_cookie?).to be(true)
    end

    it 'has profiling disabled' do
      expect(@settings.disable_profiling?).to be(true)
    end

    it 'has backtrace set to full' do
      expect(@settings.backtrace_full?).to be(true)
    end

    it 'should not write cookie changes if no change' do
      hash = {}
      @settings.write!(hash)
      expect(hash).to eq({})
    end

    it 'should correctly write cookie changes if changed' do
      @settings.disable_profiling = false
      hash = {}
      @settings.write!(hash)
      expect(hash).not_to eq({})
    end

    it 'writes auth token for authorized reqs' do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.authorize_request
      hash = {}
      @settings.write!(hash)
      expect(hash["Set-Cookie"]).to include(@store.allowed_tokens.join("|"))
    end

    it 'does nothing on short unauthed requests' do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.deauthorize_request
      hash = {}
      @settings.handle_cookie([200, hash, []])

      expect(hash).to eq({})
    end

    it 'discards on long unauthed requests' do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
      Rack::MiniProfiler.deauthorize_request
      hash = {}
      clock_travel(Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1) do
        @settings.handle_cookie([200, hash, []])
      end

      expect(hash["Set-Cookie"]).to include("max-age=0")
    end
  end

  it "should not have settings by default" do
    expect(Rack::MiniProfiler::ClientSettings.new({}, Rack::MiniProfiler::MemoryStore.new, Process.clock_gettime(Process::CLOCK_MONOTONIC))
      .has_valid_cookie?).to eq(false)
  end

end
