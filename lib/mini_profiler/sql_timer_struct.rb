require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # Timing system for a SQL query
    class SqlTimerStruct < TimerStruct
      def initialize(query, duration_ms, page, skip_backtrace = false)

        stack_trace = nil 
        unless skip_backtrace 
          # Allow us to filter the stack trace
          stack_trace = ""
           # Clean up the stack trace if there are options to do so
          Kernel.caller.each do |ln|
            ln.gsub!(Rack::MiniProfiler.configuration[:backtrace_remove], '') if Rack::MiniProfiler.configuration[:backtrace_remove]
            if Rack::MiniProfiler.configuration[:backtrace_filter].nil? or ln =~ Rack::MiniProfiler.configuration[:backtrace_filter]
              stack_trace << ln << "\n" 
            end
          end
        end

        super("ExecuteType" => 3, # TODO
              "FormattedCommandString" => query,
              "StackTraceSnippet" => stack_trace, 
              "StartMilliseconds" => ((Time.now.to_f * 1000).to_i - page['Started']) - duration_ms,
              "DurationMilliseconds" => duration_ms,
              "FirstFetchDurationMilliseconds" => 0,
              "Parameters" => nil,
              "ParentTimingId" => nil,
              "IsDuplicate" => false)
      end

    end

  end
end
