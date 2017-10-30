# frozen_string_literal: true
require 'simplecov'
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/.direnv/"
end
if ENV['CI']=='true'
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

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

class Time
  class << self
    unless method_defined? :old_new
      alias_method :old_new, :new
      alias_method :old_now, :now

      def travel(to)
        @now = to
        yield
      ensure
        @now = nil
      end

      def new
        @now || old_new
      end

      def now
        @now || old_now
      end

      def now=(v)
        @now = v
      end

      def back_to_normal
        @now = nil
      end

    end
  end
end
