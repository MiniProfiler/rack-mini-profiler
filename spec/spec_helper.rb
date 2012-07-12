Dir[File.dirname(__FILE__) + "/support/**/*.rb"].each {|f| require f}

RSpec.configure do |config|
  config.color_enabled = true
end

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
