require 'spec_helper'
require 'rack-mini-profiler'
require 'rack/test'
require 'zlib'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  before(:each) { Rack::MiniProfiler.reset_config }

  def do_get(params={})
    get '/html', params, { 'HTTP_ACCEPT_ENCODING' => 'gzip, compress' }
  end

  def decompressed_response
    Zlib::GzipReader.new(StringIO.new(last_response.body)).read
  end

  shared_examples 'should not affect a skipped requests' do
    it 'should not affect a skipped requests' do
      do_get(:pp=>'skip')
      expect(last_response.headers).to include('Content-Encoding')
      expect(last_response.headers['Content-Encoding']).to eq('gzip')
    end
  end

  describe 'with Rack::MiniProfiler before Rack::Deflater' do
    def app
      Rack::Builder.new do
        use Rack::MiniProfiler
        use Rack::Deflater
        run lambda { |_env| [200, {'Content-Type' => 'text/html'}, ['<html><body><h1>Hi</h1></body></html>']] }
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
        run lambda { |_env| [200, {'Content-Type' => 'text/html'}, ['<html><body><h1>Hi</h1></body></html>']] }
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
