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

  describe '/rack-mini-profiler/requests page' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end
    it 'is an empty page' do
      get '/rack-mini-profiler/requests', {}, 'HTTP_ACCEPT_ENCODING' => 'gzip, compress'

      expect(last_response.body).to include('<title>Rack::MiniProfiler Requests</title>')
      expect(last_response.body).to match('.*<body>\n  <script .*></script>\n</body>/*')
    end
  end

  describe '?pp=help page' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end
    it 'shows commands' do
      do_get(pp: 'help')

      expect(last_response.body).to include('<title>Rack::MiniProfiler Help</title>')
      expect(last_response.body).to include("help")
      expect(last_response.body).to include("env")
      expect(last_response.body).to include("skip")
      expect(last_response.body).to include("no-backtrace")
      expect(last_response.body).to include("normal-backtrace")
      expect(last_response.body).to include("full-backtrace")
      expect(last_response.body).to include("disable")
      expect(last_response.body).to include("enable")
      expect(last_response.body).to include("profile-gc")
      expect(last_response.body).to include("profile-memory")
      expect(last_response.body).to include("flamegraph")
      expect(last_response.body).to include("async-flamegraph")
      expect(last_response.body).to include("flamegraph&flamegraph_sample_rate=1")
      expect(last_response.body).to include("flamegraph&flamegraph_mode=cpu")
      expect(last_response.body).to include("flamegraph_embed")
      expect(last_response.body).to include("trace-exceptions")
      expect(last_response.body).to include("analyze-memory")
    end
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
        run(
          lambda do |_env|
            [
              201,
              { 'Content-Type' => 'text/html', 'X-CUSTOM' => "1" },
              [+'<html><body><h1>Hi</h1></body></html>'],
            ]
          end
        )
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
        expect(last_response.headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(last_response.headers['X-CUSTOM']).to eq('1')
        expect(last_response.status).to eq(500)
      end
    end

    describe 'with flamegraph query' do
      it 'should return stackprof error message' do
        do_get(pp: 'flamegraph')
        expect(last_response.body).to eq(
          'Please install the stackprof gem and require it: add gem \'stackprof\' to your Gemfile'
        )
        expect(last_response.headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(last_response.headers['X-CUSTOM']).to eq('1')
        expect(last_response.status).to eq(201)
      end
    end

    describe 'with async-flamegraph query' do
      it 'should return stackprof error message' do
        do_get(pp: 'async-flamegraph')
        expect(last_response.body).to eq(
          'Please install the stackprof gem and require it: add gem \'stackprof\' to your Gemfile'
        )
        expect(last_response.headers['Content-Type']).to eq('text/plain; charset=utf-8')
        expect(last_response.headers['X-CUSTOM']).to eq('1')
        expect(last_response.status).to eq(201)
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

  context 'when using a different profile parameter' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hi</h1></body></html>']] }
      end
    end

    def with_profile_parameter(param)
      old_param = Rack::MiniProfiler.config.profile_parameter
      Rack::MiniProfiler.config.profile_parameter = param
      yield
    ensure
      Rack::MiniProfiler.config.profile_parameter = old_param
    end

    it 'show help page' do
      with_profile_parameter('profile') do
        do_get(profile: 'help')
        expect(last_response.body).to include('This is the help menu')
      end
    end
  end
end
