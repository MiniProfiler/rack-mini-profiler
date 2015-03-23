module Rack
  class MiniProfiler
    module TimerStruct
      class Request < TimerStruct::Base

        def self.createRoot(name, page)
          TimerStruct::Request.new(name, page, nil).tap do |timer|
            timer[:is_root] = true
          end
        end

        def initialize(name, page, parent)
          start_millis = (Time.now.to_f * 1000).to_i - page[:Started]
          depth        = parent ? parent.depth + 1 : 0
          super(
            :Id                                      => MiniProfiler.generate_id,
            :Name                                    => name,
            :DurationMilliseconds                    => 0,
            :StartMilliseconds                       => start_millis,
            :CustomTimings                           => {},
            :Children                                => [],
            :has_children                            => false,
            :key_values                              => nil,
            :has_sql_timings                         => false,
            :has_duplicate_sql_timings               => false,
            :trivial_duration_threshold_milliseconds => 2,
            :sql_timings                             => [],
            :sql_timings_duration_milliseconds       => 0,
            :is_trivial                              => false,
            :is_root                                 => false,
            :depth                                   => depth
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

        def depth
          self[:depth]
        end

        def children
          self[:Children]
        end

        def custom_timings
          self[:CustomTimings]
        end

        def sql_timings
          self[:sql_timings]
        end

        def add_child(name)
          TimerStruct::Request.new(name, @page, self).tap do |timer|
            children.push(timer)
            self[:has_children]      = true
            timer[:depth]            = self[:depth] + 1
          end
        end

        def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
          TimerStruct::Sql.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace).tap do |timer|
            self[:sql_timings].push(timer)
            self[:has_sql_timings]   = true
            self[:sql_timings_duration_milliseconds] += elapsed_ms
            page[:duration_milliseconds_in_sql]      += elapsed_ms
          end
        end

        def add_custom(type, elapsed_ms, page)
          TimerStruct::Custom.new(type, elapsed_ms, page, self).tap do |timer|
            self.custom_timings[type] ||= []
            self.custom_timings[type].push(timer)
          end
        end

        def record_time(milliseconds = nil)
          milliseconds ||= (Time.now - @start) * 1000
          self[:DurationMilliseconds]                   = milliseconds
          self[:is_trivial]                             = true if milliseconds < self[:trivial_duration_threshold_milliseconds]
        end

      end
    end
  end
end
