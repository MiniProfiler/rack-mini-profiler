require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # Timing system for a custom timers such as cache, redis, RPC, external API
    # calls, etc.
    class CustomTimerStruct < TimerStruct
      def initialize(type, duration_ms, page, parent)
        @parent      = parent
        @page        = page
        @type        = type
        start_millis = ((Time.now.to_f * 1000).to_i - page['Started']) - duration_ms
        super(
          "Type"                 => type,
          "StartMilliseconds"    => start_millis,
          "DurationMilliseconds" => duration_ms,
          "ParentTimingId"       => nil
        )
      end
    end

  end
end
