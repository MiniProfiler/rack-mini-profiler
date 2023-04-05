# frozen_string_literal: true

$VERBOSE = true
require 'webmock/rspec'
require 'simplecov'

SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.direnv/"
end
# if ENV['CI'] == 'true'
#   require 'codecov'
#   SimpleCov.formatter = SimpleCov::Formatter::Codecov
# end

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect # Disable `should`
  end

  config.filter_run :focus

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect # Disable `should_receive` and `stub`
    mocks.verify_partial_doubles = true
  end

  Kernel.srand config.seed

  config.run_all_when_everything_filtered = true
end

require 'rack-mini-profiler'

module Process

  unless respond_to? :old_clock_gettime
    class << self
      alias_method :old_clock_gettime, :clock_gettime
    end

    def clock_set(to)
      @now = to
    end
    module_function :clock_set

    def clock_travel(to)
      @now = to
      yield
    ensure
      @now = nil
    end
    module_function :clock_travel

    undef clock_gettime
    def clock_gettime(*)
      defined?(@now) && @now || old_clock_gettime(Process::CLOCK_MONOTONIC)
    end
    module_function :clock_gettime

    def back_to_normal
      @now = nil
    end
    module_function :back_to_normal
  end
end

def clock_set(to)
  Process.clock_set(to)
end

def clock_travel(to, &block)
  Process.clock_travel(to) { yield }
end

def clock_back_to_normal
  Process.back_to_normal
end
