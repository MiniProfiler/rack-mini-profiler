# frozen_string_literal: true
require 'rack/test'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/path2/a' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>path1</h1>'] }
      end
      map '/path1/a' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>path2</h1>'] }
      end
      map '/cached-resource' do
        run lambda { |env|
          ims = env['HTTP_IF_MODIFIED_SINCE'] || ""
          if ims.size > 0
            [304, {'Content-Type' => 'application/json'}, '']
          else
            [200, {'Content-Type' => 'application/json', 'Cache-Control' => 'original-cache-control'}, '{"name": "Ryan"}']
          end
        }
      end
      map '/post' do
        run lambda { |env| [302, {'Content-Type' => 'text/html'}, '<h1>POST</h1>'] }
      end
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, "<html><BODY><h1>Hi</h1></BODY>\n \t</html>"] }
      end
      map '/whitelisted-html' do
        run lambda { |env|
          Rack::MiniProfiler.authorize_request
          [200, {'Content-Type' => 'text/html'}, "<html><BODY><h1>Hi</h1></BODY>\n \t</html>"]
        }
      end
      map '/implicitbody' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, "<html><h1>Hi</h1></html>"] }
      end
      map '/implicitbodyhtml' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, "<h1>Hi</h1>"] }
      end
      map '/db' do
        run lambda { |env|
          ::Rack::MiniProfiler.record_sql("I want to be, in a db", 10)
          [200, {'Content-Type' => 'text/html'}, '<h1>Hi+db</h1>']
        }
      end
      map '/3ms' do
        run lambda { |env|
          sleep(0.003)
          [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1>']
        }
      end
      map '/whitelisted' do
        run lambda { |env|
          Rack::MiniProfiler.authorize_request
          [200, {'Content-Type' => 'text/html'}, '<h1>path1</h1>']
        }
      end
      map '/rails_engine' do
        run lambda { |env|
          env['SCRIPT_NAME'] = '/rails_engine'  # Rails engines do that
          [200, {'Content-Type' => 'text/html'}, '<html><h1>Hi</h1></html>']
        }
      end
      map '/under_passenger' do
        run lambda { |env|
          [200, {'Content-Type' => 'text/html'}, '<html><h1>and I ride and I ride</h1></html>']
        }
      end
    }.to_app
  end

  before do
    Rack::MiniProfiler.reset_config
  end

  describe 'with a valid request' do

    before do
      get '/html'
    end

    it 'returns 200' do
      expect(last_response).to be_ok
    end

    it 'has the X-MiniProfiler-Ids header' do
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end

    it 'has only one X-MiniProfiler-Ids header' do
      h = last_response.headers['X-MiniProfiler-Ids']
      ids = ::JSON.parse(h)
      expect(ids.count).to eq(1)
    end

    it 'has the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(true)
    end

    it 'has a functioning share link' do
      h = last_response.headers['X-MiniProfiler-Ids']
      id = ::JSON.parse(h)[0]
      get "/mini-profiler-resources/results?id=#{id}"
      expect(last_response).to be_ok
    end

    it 'avoids xss attacks' do
      h = last_response.headers['X-MiniProfiler-Ids']
      _id = ::JSON.parse(h)[0]
      get "/mini-profiler-resources/results?id=%22%3E%3Cqss%3E"
      expect(last_response).not_to be_ok
      expect(last_response.body).not_to match(/<qss>/)
      expect(last_response.body).to match(/&lt;qss&gt;/)
    end
  end


  describe 'with an implicit body tag' do

    before do
      get '/implicitbody'
    end

    it 'has the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(true)
    end

  end


  describe 'with implicit body and html tags' do

    before do
      get '/implicitbodyhtml'
    end

    it 'does not include the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(false)
    end

  end

  describe 'with a SCRIPT_NAME' do

    before do
      get '/html', nil, 'SCRIPT_NAME' => '/test'
    end

    it 'has the JS in the body with the correct path' do
      expect(last_response.body.include?('/test/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'within a rails engine' do

    before do
      get '/rails_engine'
    end

    it 'include the correct JS in the body' do
      expect(last_response.body.include?('/rails_engine/mini-profiler-resources/includes.js')).not_to be(true)
      expect(last_response.body.include?('src="/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'under passenger' do

    before do
      ENV['PASSENGER_BASE_URI'] = '/under_passenger'
    end

    after do
      ENV['PASSENGER_BASE_URI'] = nil
    end

    it 'include the correct JS in the body' do
      get '/under_passenger'
      expect(last_response.body.include?('src="/under_passenger/mini-profiler-resources/includes.js')).to be(true)
    end

  end


  describe 'configuration' do
    it "should remove caching headers by default" do
      get '/cached-resource'
      expect(last_response.headers['X-MiniProfiler-Original-Cache-Control']).to eq('original-cache-control')
      expect(last_response.headers['Cache-Control']).to include('no-store')
    end

    it "should not store the original cache header if not set" do
      get '/html'
      last_response.headers.should_not have_key('X-MiniProfiler-Original-Cache-Control')
    end

    it "should strip if-modified-since on the way in" do
      old_time = 1409326086
      get '/cached-resource', {}, {'HTTP_IF_MODIFIED_SINCE' => old_time}
      expect(last_response.status).to equal(200)
    end

    describe 'with caching re-enabled' do
      before :each do
        Rack::MiniProfiler.config.disable_caching = false
      end

      it "should strip if-modified-since on the way in" do
        old_time = 1409326086
        get '/cached-resource', {}, {'HTTP_IF_MODIFIED_SINCE' => old_time}
        expect(last_response.status).to equal(304)
      end


      it "should be able to re-enable caching" do
        get '/cached-resource'
        expect(last_response.headers['X-MiniProfiler-Original-Cache-Control']).to eq('original-cache-control')
        expect(last_response.headers['Cache-Control']).not_to include('no-store')
      end
    end

    it "doesn't add MiniProfiler if the callback fails" do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda {|env| false }
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end

    it "skips paths listed" do
      Rack::MiniProfiler.config.skip_paths = ['/path/', '/path2/']
      get '/path2/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
      get '/path1/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end

    it 'disables default functionality' do
      Rack::MiniProfiler.config.enabled = false
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end
  end

  def load_prof(response)
    id = response.headers['X-MiniProfiler-Ids']
    id = ::JSON.parse(id)[0]
    Rack::MiniProfiler.config.storage_instance.load(id)
  end

  describe 'special options' do
    it "omits db backtrace if requested" do
      get '/db?pp=no-backtrace'
      prof = load_prof(last_response)
      stack = prof[:root][:sql_timings][0][:stack_trace_snippet]
      expect(stack).to be_nil
    end

    it 'disables functionality if requested' do
      get '/html?pp=disable'
      expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
    end

    context 'when disabled' do
      before(:each) do
        get '/html?pp=disable'
        get '/html'
        expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
      end

      it 're-enables functionality if requested' do
        get '/html?pp=enable'
        expect(last_response.body).to include('/mini-profiler-resources/includes.js')
      end

      it "does not re-enable functionality if not whitelisted" do
        Rack::MiniProfiler.config.authorization_mode = :whitelist
        get '/html?pp=enable'
        get '/html?pp=enable'
        expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
      end

      it "re-enabled functionality if whitelisted" do
        Rack::MiniProfiler.config.authorization_mode = :whitelist
        get '/whitelisted-html?pp=enable'
        get '/whitelisted-html?pp=enable'
        expect(last_response.body).to include('/mini-profiler-resources/includes.js')
      end
    end

    describe 'disable_env_dump config option' do
      context 'default (not configured' do
        it 'allows env dump' do
          get '/html?pp=env'

          expect(last_response.body).to include('QUERY_STRING')
          expect(last_response.body).to include('CONTENT_LENGTH')
        end
      end
      context 'when enabled' do
        it 'disables dumping the ENV over the web' do
          Rack::MiniProfiler.config.disable_env_dump = true
          get '/html?pp=env'

          # Contains no ENV vars:
          expect(last_response.body).not_to include('QUERY_STRING')
          expect(last_response.body).not_to include('CONTENT_LENGTH')
        end
      end
    end
  end

  describe 'POST followed by GET' do
    it "should end up with 2 ids" do
      post '/post'
      get '/html'

      ids = last_response.headers['X-MiniProfiler-Ids']
      expect(::JSON.parse(ids).length).to eq(2)
    end
  end

  describe 'authorization mode whitelist' do
    before do
      Rack::MiniProfiler.config.authorization_mode = :whitelist
    end

    it "should ban requests that are not whitelisted" do
      get '/html'
      expect(last_response.headers['X-MiniProfiler-Ids']).to be_nil
    end

    it "should allow requests that are whitelisted" do
      get '/whitelisted'
      # second time will ensure cookie is set
      # first time around there is no cookie, so no profiling
      get '/whitelisted'
      expect(last_response.headers['X-MiniProfiler-Ids']).not_to be_nil
    end
  end


  describe 'gc profiler' do
    it "should return a report" do
      get '/html?pp=profile-gc'
      expect(last_response.header['Content-Type']).to eq('text/plain')
    end
  end

  describe 'error handling when storage_instance fails to save' do
    it "should recover gracefully" do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda {|env| true }
      allow_any_instance_of(Rack::MiniProfiler::MemoryStore).to receive(:save) { raise "This error" }
      expect(Rack::MiniProfiler.config.storage_failure).to receive(:call)
      get '/html'
    end
  end

  describe 'when profiler is disabled by default' do
    before(:each) do
      Rack::MiniProfiler.config.enabled = false
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end

    it 'functionality can be re-enabled' do
      get '/html?pp=enable'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end
  end

end
