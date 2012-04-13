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

    it 'has the X-MiniProfilerID header' do
      last_response.headers.has_key?('X-MiniProfilerID').should be_true
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


end
