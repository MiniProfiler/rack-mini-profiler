require 'spec_helper'
require 'rack-mini-profiler'
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
      map '/post' do
        run lambda { |env| [302, {'Content-Type' => 'text/html'}, '<h1>POST</h1>'] }
      end
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1>'] }
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
      last_response.should be_ok
    end

    it 'has the X-MiniProfiler-Ids header' do
      last_response.headers.has_key?('X-MiniProfiler-Ids').should be_true
    end

    it 'has only one X-MiniProfiler-Ids header' do
      h = last_response.headers['X-MiniProfiler-Ids']
      ids = ::JSON.parse(h)
      ids.count.should == 1
    end

    it 'has the JS in the body' do
      last_response.body.include?('MiniProfiler.init').should be_true
    end

  end

  describe 'configuration' do
    it "doesn't add MiniProfiler if the callback fails" do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda {|env| false }
      get '/html'
      last_response.headers.has_key?('X-MiniProfiler-Ids').should be_false
    end

    it "skips paths listed" do 
      Rack::MiniProfiler.config.skip_paths = ['/path/', '/path2/']
      get '/path2/a'
      last_response.headers.has_key?('X-MiniProfiler-Ids').should be_false
      get '/path1/a'
      last_response.headers.has_key?('X-MiniProfiler-Ids').should be_true
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
      stack = prof["Root"]["SqlTimings"][0]["StackTraceSnippet"]
      stack.should be_nil
    end
    
  end

  describe 'POST followed by GET' do
    it "should end up with 2 ids" do
      post '/post'
      get '/html'

      ids = last_response.headers['X-MiniProfiler-Ids']
      ::JSON.parse(ids).length.should == 2
    end
  end
  
  describe 'sampling mode' do
    it "should sample stack traces if requested" do 
      get '/3ms?pp=sample' 
      last_response["Content-Type"].should == 'text/plain'
    end
  end


  describe 'authorization mode whitelist' do
    before do 
      Rack::MiniProfiler.config.authorization_mode = :whitelist
    end

    it "should ban requests that are not whitelisted" do 
      get '/html'
      last_response.headers['X-MiniProfiler-Ids'].should be_nil
    end

    it "should allow requests that are whitelisted" do 
      set_cookie("__profilin=stylin")
      get '/whitelisted'
      last_response.headers['X-MiniProfiler-Ids'].should_not be_nil
    end
  end


end
