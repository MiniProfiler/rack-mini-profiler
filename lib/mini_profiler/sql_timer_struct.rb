module Rack
  class MiniProfiler

    # Timing system for a SQL query
    class SqlTimerStruct
      def initialize(query, duration_ms, page)
        @attributes = {
          "ExecuteType" => 3, # TODO
          "FormattedCommandString" => query,
          "StackTraceSnippet" => Kernel.caller.join("\n"), # TODO
          "StartMilliseconds" => (Time.now.to_f * 1000).to_i - page['Started'],
          "DurationMilliseconds" => duration_ms,
          "FirstFetchDurationMilliseconds" => 0,
          "Parameters" => nil,
          "ParentTimingId" => nil,
          "IsDuplicate" => false
        }
      end

      def to_json(*a)
        ::JSON.generate(@attributes, *a)
      end

      def []=(name, val)
        @attributes[name] = val
      end

      def [](name)
        @attributes[name]
      end
    end

  end
end
