# frozen_string_literal: true

require 'rack'
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
      expect(last_response.body).to match('<body>\n  <script async nonce="" type="text/javascript" id="mini-profiler"')
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
      expect(last_response.body).to include("flamegraph&flamegraph_ignore_gc=true")
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

  context "with CSP nonce" do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        run lambda { |env|
          env["action_dispatch.content_security_policy_nonce"] = "railsnonce"
          [200, { 'Content-Type' => 'text/html' }, [+'<html><body><h1>Hello world</h1></body></html>']]
        }
      end
    end

    it 'uses Rails value when available' do
      do_get
      expect(last_response.body).to include("nonce=\"railsnonce\"")
    end

    it 'uses configured string when available' do
      Rack::MiniProfiler.config.content_security_policy_nonce = "configurednonce"
      do_get
      expect(last_response.body).to include("nonce=\"configurednonce\"")
    end

    it 'calls configured block when available' do
      proc_arguments = nil

      Rack::MiniProfiler.config.content_security_policy_nonce = Proc.new do |env, response_headers|
        proc_arguments = [env, response_headers]
        "dynamicnonce"
      end

      do_get
      expect(last_response.body).to include("nonce=\"dynamicnonce\"")

      (env, response_headers) = proc_arguments
      expect(env["REQUEST_METHOD"]).to eq("GET")
      expect(response_headers["Content-Type"]).to eq("text/html")
    end

  end

  context 'flamegraph with CSP nonce' do
    class CSPMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        env["action_dispatch.content_security_policy_nonce"] = "railsflamenonce"
        @app.call(env)
      end
    end

    def app
      Rack::Builder.new do
        use CSPMiddleware
        use Rack::MiniProfiler
        run lambda { |env|
          [200, { 'Content-Type' => 'text/html' }, ['<html><body><h1>Hello</h1></body></html>']]
        }
      end
    end

    def do_flamegraph_test
      pid = fork do # Avoid polluting main process with stackprof
        require 'stackprof'

        get '/html?pp=async-flamegraph'
        expect(last_response).to be_ok
        flamegraph_path = last_response.headers['X-MiniProfiler-Flamegraph-Path']

        get flamegraph_path
        expect(last_response).to be_ok
        yield last_response.body
      end

      Process.wait(pid)
      expect($?.exitstatus).to eq(0)
    end

    it 'uses Rails value when available' do
      do_flamegraph_test do |body|
        expect(body).to include('<script type="text/javascript" nonce="railsflamenonce">')
      end
    end

    it 'uses configured string when available' do
      Rack::MiniProfiler.config.content_security_policy_nonce = "configuredflamenonce"

      do_flamegraph_test do |body|
        expect(body).to include('<script type="text/javascript" nonce="configuredflamenonce">')
      end
    end

    it 'calls configured block when available' do
      Rack::MiniProfiler.config.content_security_policy_nonce = Proc.new { "dynamicflamenonce" }

      do_flamegraph_test do |body|
        expect(body).to include('<script type="text/javascript" nonce="dynamicflamenonce">')
      end
    end
  end
end
