module Rack
  class MiniProfiler

    # Timing system for a SQL query
    module TimerStruct
      class Sql < TimerStruct::Base
        def initialize(query, duration_ms, page, parent, skip_backtrace = false, full_backtrace = false)

          stack_trace = nil
          unless skip_backtrace || duration_ms < Rack::MiniProfiler.config.backtrace_threshold_ms
            # Allow us to filter the stack trace
            stack_trace = ""
             # Clean up the stack trace if there are options to do so
            Kernel.caller.each do |ln|
              ln.gsub!(Rack::MiniProfiler.config.backtrace_remove, '') if Rack::MiniProfiler.config.backtrace_remove and !full_backtrace
              if    full_backtrace or
                    (
                      (
                        Rack::MiniProfiler.config.backtrace_includes.nil? or
                        Rack::MiniProfiler.config.backtrace_includes.all?{|regex| ln =~ regex}
                      ) and
                      (
                        Rack::MiniProfiler.config.backtrace_ignores.nil? or
                        Rack::MiniProfiler.config.backtrace_ignores.all?{|regex| !(ln =~ regex)}
                      )
                    )
                stack_trace << ln << "\n"
              end
            end
          end

          @parent      = parent
          @page        = page
          start_millis = ((Time.now.to_f * 1000).to_i - page[:Started]) - duration_ms
          super(
            :ExecuteType                    => 3, # TODO
            :CommandString                  => query,
            :StackTraceSnippet              => stack_trace,
            :StartMilliseconds              => start_millis,
            :DurationMilliseconds           => duration_ms,
            :FirstFetchDurationMilliseconds => duration_ms
          )
        end

        def report_reader_duration(elapsed_ms)
          return if @reported
          @reported = true
          self[:DurationMilliseconds] += elapsed_ms
        end

      end
    end
  end
end
