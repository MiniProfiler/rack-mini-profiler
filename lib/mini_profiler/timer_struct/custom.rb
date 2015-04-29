module Rack
  class MiniProfiler
    module TimerStruct
      # Timing system for a custom timers such as cache, redis, RPC, external API
      # calls, etc.
      class Custom < TimerStruct::Base
        def initialize(duration_ms, page, parent)
          @parent      = parent
          @page        = page
          start_millis = ((Time.now.to_f * 1000).to_i - page[:Started]) - duration_ms
          super(
            :StartMilliseconds    => start_millis,
            :DurationMilliseconds => duration_ms
          )
        end
      end
    end
  end
end
