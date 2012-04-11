require 'spec_helper'
require 'profiler/profiler'
require 'rack/test'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/html' do
        run lambda { |env| [200, {'Content-Type' => 'text/html'}, '<h1>Hi</h1'] }
      end
    }.to_app
  end

  it 'returns 200' do
    get '/html'
    last_response.status.should == 200
  end

end
