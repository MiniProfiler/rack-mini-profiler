require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # Timing system for a custom timers such as cache, redis, RPC, external API
    # calls, etc.
    class CustomTimerStruct < TimerStruct
      def initialize(type, duration_ms, page, parent)
        @parent = parent
        @page = page
        @type = type

        super(:type => type,
              :start_milliseconds => ((Time.now.to_f * 1000).to_i - page[:started]) - duration_ms,
              :duration_milliseconds => duration_ms,
              :parent_timing_id => nil)
      end
    end

  end
end
