# frozen_string_literal: true

require 'rack/test'
require 'zlib'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  before(:each) { Rack::MiniProfiler.reset_config }

  def do_get(params = {})
    get '/html', params, 'HTTP_ACCEPT_ENCODING' => 'gzip, compress'
  end

  def decompressed_response
    Zlib::GzipReader.new(StringIO.new(last_response.body)).read
  end

  shared_examples 'should not affect a skipped requests' do
    it 'should not affect a skipped requests' do
      do_get(pp: 'skip')
      expect(last_response.headers).to include('Content-Encoding')
      expect(last_response.headers['Content-Encoding']).to eq('gzip')
    end
  end

  describe 'when enable_advanced_debugging_tools is false' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end
    it 'advanced tools are disabled' do
      %w{env analyze-memory profile-gc profile-memory}.each do |p|
        do_get(pp: p)
        expect(last_response.body).to eq(Rack::MiniProfiler.advanced_tools_message)
      end
    end
  end

  describe 'when enable_advanced_debugging_tools is true' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end

    before(:each) { Rack::MiniProfiler.config.enable_advanced_debugging_tools = true }

    describe 'with analyze-memory query' do
      it 'should return ObjectSpace statistics' do
        do_get(pp: 'analyze-memory')
        expect(last_response.body).to include('Largest strings:')
      end
    end

    describe 'with profile-memory query' do
      it 'should return memory_profiler error message' do
        do_get(pp: 'profile-memory')
        expect(last_response.body).to eq(
          'Please install the memory_profiler gem and require it: add gem \'memory_profiler\' to your Gemfile'
        )
      end
    end

    describe 'with flamegraph query' do
      it 'should return stackprof error message' do
        Rack::MiniProfiler.config.enable_advanced_debugging_tools = true
        do_get(pp: 'flamegraph')
        expect(last_response.body).to eq(
          'Please install the stackprof gem and require it: add gem \'stackprof\' to your Gemfile'
        )
      end
    end
  end

  describe 'with Rack::MiniProfiler before Rack::Deflater' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        use Rack::Deflater
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end

    describe 'with suppress_encoding true' do
      before { Rack::MiniProfiler.config.suppress_encoding = true }

      it 'should inject script and *not* compress' do
        do_get
        expect(last_response.body).to include('/mini-profiler-resources/includes.js')
        expect(last_response.headers).not_to include('Content-Encoding')
      end

      include_examples 'should not affect a skipped requests'
    end

    describe 'with suppress_encoding false' do
      before { Rack::MiniProfiler.config.suppress_encoding = false }

      it 'should *not* inject script but should compress' do
        do_get
        expect(decompressed_response).not_to include('/mini-profiler-resources/includes.js')
        expect(last_response.headers['Content-Encoding']).to eq('gzip')
      end

      include_examples 'should not affect a skipped requests'
    end

  end

  describe 'with Rack::Deflater before Rack::MiniProfiler' do

    def app
      Rack::Builder.new do
        use Rack::Deflater
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end

    describe 'with suppress_encoding true' do
      before { Rack::MiniProfiler.config.suppress_encoding = true }

      it 'should inject script and compress' do
        do_get
        expect(decompressed_response).to include('/mini-profiler-resources/includes.js')
        expect(last_response.headers['Content-Encoding']).to eq('gzip')
      end

      include_examples 'should not affect a skipped requests'
    end

    describe 'with suppress_encoding false' do
      before { Rack::MiniProfiler.config.suppress_encoding = false }

      it 'should inject script and compress' do
        do_get
        expect(decompressed_response).to include('/mini-profiler-resources/includes.js')
        expect(last_response.headers['Content-Encoding']).to eq('gzip')
      end

      include_examples 'should not affect a skipped requests'
    end
  end

end
