module Rack
  class MiniProfiler

    # This class acts as a proxy to the Body so that we can
    # safely append to the end without knowing about the internals
    # of the body class.    
    class BodyAddProxy
      def initialize(body, additional_text)
        @body = body
        @additional_text = additional_text
      end

      def respond_to?(*args)
        super or @body.respond_to?(*args)
      end

      def method_missing(*args, &block)
        @body.__send__(*args, &block)
      end

      def each(&block)
        @body.each(&block)
        yield @additional_text
        self
      end
    end

  end
end
