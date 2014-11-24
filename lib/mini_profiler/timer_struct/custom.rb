module Rack
  class MiniProfiler
    module TimerStruct
      # Timing system for a custom timers such as cache, redis, RPC, external API
      # calls, etc.
      class Custom < TimerStruct::Base
        def initialize(type, duration_ms, page, parent)
          @parent      = parent
          @page        = page
          @type        = type
          start_millis = ((Time.now.to_f * 1000).to_i - page[:started]) - duration_ms
          super(
            :type                  => type,
            :start_milliseconds    => start_millis,
            :duration_milliseconds => duration_ms,
            :parent_timing_id      => nil
          )
        end
      end
    end
  end
end
