# frozen_string_literal: true

# Note: This test is highly dependent on line numbers for backtrace details
# Take care when changing the structure of this file and update tests accordingly

require 'rack/test'

describe 'Rack::MiniProfiler - trace_exceptions' do
  include Rack::Test::Methods

  before(:each) { Rack::MiniProfiler.reset_config }

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/no_exceptions' do
        run lambda { |_env| [200, { 'Content-Type' => 'text/html' }, '<h1>Success</h1>'] }
      end
      map '/raise_exceptions' do
        # This route raises 3 exceptions, catches them, and returns a successful response
        run lambda { |_env|
          begin
            raise 'Test RuntimeError Exception'
          rescue
            # Ignore the exception
          end
          begin
            raise NameError, 'Test NameError Exception'
          rescue
            # Ignore the exception
          end
          begin
            raise NoMethodError, 'Test NoMethodError Exception'
          rescue
            # Ignore the exception
          end
          [200, { 'Content-Type' => 'text/html' }, '<h1>Exception raised but success returned</h1>']
        }
      end
    }.to_app
  end

  it 'with no exceptions' do
    get '/no_exceptions', pp: 'trace-exceptions'
    expect(last_response.body).to include('No exceptions')
  end

  describe 'with exceptions' do
    it 'unfiltered' do
      get '/raise_exceptions', pp: 'trace-exceptions'
      expect(last_response.body).to include('Exceptions: (3 total)')
      expect(last_response.body).to include('RuntimeError - "Test RuntimeError Exception"')
      expect(last_response.body).to include('NameError - "Test NameError Exception"')
      expect(last_response.body).to include('NoMethodError - "Test NoMethodError Exception"')
      expect(last_response.body).to include("  #{__FILE__}")
    end

    it 'with a single filtered exception' do
      get '/raise_exceptions', :pp => 'trace-exceptions', 'trace_exceptions_filter' => 'RuntimeError'
      expect(last_response.body).to include('Exceptions: (2 total)')
      expect(last_response.body).not_to include('RuntimeError - "Test RuntimeError Exception"')
      expect(last_response.body).to include('NameError - "Test NameError Exception"')
      expect(last_response.body).to include('NoMethodError - "Test NoMethodError Exception"')
      expect(last_response.body).not_to include("  #{__FILE__}:23")
      expect(last_response.body).to include("  #{__FILE__}:28")
      expect(last_response.body).to include("  #{__FILE__}:33")
    end

    it 'with a multiple filtered exceptions' do
      get '/raise_exceptions', :pp => 'trace-exceptions', 'trace_exceptions_filter' => 'NameError|NoMethodError'
      expect(last_response.body).to include('Exceptions: (1 total)')
      expect(last_response.body).to include('RuntimeError - "Test RuntimeError Exception"')
      expect(last_response.body).not_to include('NameError - "Test NameError Exception"')
      expect(last_response.body).not_to include('NoMethodError - "Test NoMethodError Exception"')
      expect(last_response.body).to include("  #{__FILE__}:23")
      expect(last_response.body).not_to include("  #{__FILE__}:28")
      expect(last_response.body).not_to include("  #{__FILE__}:33")
    end

  end

end
