require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # Timing system for a SQL query
    class SqlTimerStruct < TimerStruct
      def initialize(query, duration_ms, page)
        super("ExecuteType" => 3, # TODO
              "FormattedCommandString" => query,
              "StackTraceSnippet" => Kernel.caller.join("\n"), # TODO
              "StartMilliseconds" => (Time.now.to_f * 1000).to_i - page['Started'],
              "DurationMilliseconds" => duration_ms,
              "FirstFetchDurationMilliseconds" => 0,
              "Parameters" => nil,
              "ParentTimingId" => nil,
              "IsDuplicate" => false)
      end

    end

  end
end
