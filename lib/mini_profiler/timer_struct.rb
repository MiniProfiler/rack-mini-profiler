module Rack
  class MiniProfiler

    # A base class for timing structures
    class TimerStruct

      def initialize(attrs={})
        @attributes = attrs
      end

      def attributes
        @attributes ||= {}
      end

      def [](name)
        attributes[name]
      end

      def []=(name, val)
        attributes[name] = val
        self
      end

      def to_json(*a)
        ::JSON.generate(@attributes, a[0])
      end

    end

  end
end
