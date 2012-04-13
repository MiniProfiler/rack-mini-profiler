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

      # In the case of to_str we don't want to use method_missing as it might avoid
      # a call to each (such as in Rack::Test)
      def to_str
        result = ""
        each {|token| result << token}
        result
      end

      def each(&block)

        # In ruby 1.9 we don't support String#each
        if @body.is_a?(String)
          yield @body
        else
          @body.each(&block)
        end

        yield @additional_text
        self
      end

    end

  end
end
