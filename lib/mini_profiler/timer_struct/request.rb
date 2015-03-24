module Rack
  class MiniProfiler
    module TimerStruct
      class Request < TimerStruct::Base

        def self.createRoot(name, page)
          TimerStruct::Request.new(name, page, nil)
        end

        def initialize(name, page, parent)
          start_millis = (Time.now.to_f * 1000).to_i - page[:Started]
          super(
            :Id                    => MiniProfiler.generate_id,
            :Name                  => name,
            :DurationMilliseconds  => 0,
            :StartMilliseconds     => start_millis,
            :CustomTimings         => {},
            :Children              => []
          )
          @start             = Time.now
          @parent            = parent
          @page              = page
        end

        def duration_ms
          self[:DurationMilliseconds]
        end

        def start_ms
          self[:StartMilliseconds]
        end

        def start
          @start
        end

        def children
          self[:Children]
        end

        def custom_timings
          self[:CustomTimings]
        end

        def sql_timings
          custom_timings[:sql] ||= []
        end

        def add_child(name)
          TimerStruct::Request.new(name, @page, self).tap do |timer|
            children.push(timer)
          end
        end

        def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
          TimerStruct::Sql.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace).tap do |timer|
            sql_timings.push(timer)
          end
        end

        def add_custom(type, elapsed_ms, page)
          TimerStruct::Custom.new(elapsed_ms, page, self).tap do |timer|
            self.custom_timings[type] ||= []
            self.custom_timings[type].push(timer)
          end
        end

        def record_time(milliseconds = nil)
          milliseconds ||= (Time.now - @start) * 1000
          self[:DurationMilliseconds] = milliseconds
        end

      end
    end
  end
end
