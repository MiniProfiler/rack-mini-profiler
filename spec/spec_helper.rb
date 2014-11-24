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
  config.color_enabled = true
end

require 'rack-mini-profiler'

class Time
  class << self
    unless method_defined? :old_new
      alias_method :old_new, :new
      alias_method :old_now, :now

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
