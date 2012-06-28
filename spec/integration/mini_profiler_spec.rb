require 'spec_helper'
require 'rack-mini-profiler'
require 'rack/test'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/post' do
        run lambda { |env| [302, {'Content-Type' => 'text/html'}, '<h1>POST</h1>'] }
      end
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1>'] }
      end
      map '/db' do 
        run lambda { |env| 
          ::Rack::MiniProfiler.instance.record_sql("I want to be, in a db", 10)
          [200, {'Content-Type' => 'text/html'}, '<h1>Hi+db</h1>'] 
        }
      end
      map '/3ms' do 
        run lambda { |env| 
          sleep(0.003)
          [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1>'] 
        }
      end
    }.to_app
  end

  before do
    Rack::MiniProfiler.reset_configuration
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
      Rack::MiniProfiler.configuration[:authorize_cb] = lambda {|env| false }
      get '/html'
      last_response.headers.has_key?('X-MiniProfilerID').should be_false
    end
  end

  def load_prof(response)
    id = response.headers['X-MiniProfiler-Ids']
    id = ::JSON.parse(id)[0]
    Rack::MiniProfiler.configuration[:storage_instance].load(id)
  end

  describe 'special options' do
    it "omits db backtrace if requested" do 
      get '/db?pp=skip-backtrace' 
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
      prof = load_prof(last_response)

      # TODO: implement me
      #prof["Root"]["SampleData"].length should > 0 

    end
  end


end
