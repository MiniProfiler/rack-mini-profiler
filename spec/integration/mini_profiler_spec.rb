require 'spec_helper'
require 'rack-mini-profiler'
require 'rack/test'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1>'] }
      end
      map '/db' do 
        run lambda { |env| 
          ::Rack::MiniProfiler.instance.record_sql("I want to be, in a db", 10)
          [200, {'Content-Type' => 'text/html'}, '<h1>Hi+db</h1>'] 
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

  describe 'special options' do
    it "omits db backtrace if requested" do 
      get '/db?pp=skip-backtrace' 
      id = last_response.headers['X-MiniProfiler-Ids']
      id = ::JSON.parse(id)[0]
      prof = Rack::MiniProfiler.configuration[:storage_instance].load(id)
      stack = prof["Root"]["SqlTimings"][0]["StackTraceSnippet"]
      stack.should be_nil
    end
    
  end


end
