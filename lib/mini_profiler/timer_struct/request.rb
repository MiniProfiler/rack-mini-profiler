module Rack
  class MiniProfiler
    module TimerStruct
      class Request < TimerStruct::Base

        def self.createRoot(name, page)
          TimerStruct::Request.new(name, page, nil).tap do |timer|
            timer[:is_root] = true
          end
        end

        attr_accessor :children_duration

        def initialize(name, page, parent)
          start_millis = (Time.now.to_f * 1000).to_i - page[:started]
          depth        = parent ? parent.depth + 1 : 0
          super(
            :id                                      => MiniProfiler.generate_id,
            :name                                    => name,
            :duration_milliseconds                   => 0,
            :duration_without_children_milliseconds  => 0,
            :start_milliseconds                      => start_millis,
            :parent_timing_id                        => nil,
            :children                                => [],
            :has_children                            => false,
            :key_values                              => nil,
            :has_sql_timings                         => false,
            :has_duplicate_sql_timings               => false,
            :trivial_duration_threshold_milliseconds => 2,
            :sql_timings                             => [],
            :sql_timings_duration_milliseconds       => 0,
            :is_trivial                              => false,
            :is_root                                 => false,
            :depth                                   => depth,
            :executed_readers                        => 0,
            :executed_scalars                        => 0,
            :executed_non_queries                    => 0,
            :custom_timing_stats                     => {},
            :custom_timings                          => {}
          )
          @children_duration = 0
          @start             = Time.now
          @parent            = parent
          @page              = page
        end

        def name
          @attributes[:name]
        end

        def duration_ms
          self[:duration_milliseconds]
        end

        def duration_ms_in_sql
          @attributes[:duration_milliseconds_in_sql]
        end

        def start_ms
          self[:start_milliseconds]
        end

        def start
          @start
        end

        def depth
          self[:depth]
        end

        def children
          self[:children]
        end

        def custom_timings
          self[:custom_timings]
        end

        def sql_timings
          self[:sql_timings]
        end

        def add_child(name)
          TimerStruct::Request.new(name, @page, self).tap do |timer|
            self[:children].push(timer)
            self[:has_children]      = true
            timer[:parent_timing_id] = self[:id]
            timer[:depth]            = self[:depth] + 1
          end
        end

        def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
          TimerStruct::Sql.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace).tap do |timer|
            self[:sql_timings].push(timer)
            timer[:parent_timing_id] = self[:id]
            self[:has_sql_timings]   = true
            self[:sql_timings_duration_milliseconds] += elapsed_ms
            page[:duration_milliseconds_in_sql]      += elapsed_ms
          end
        end

        def add_custom(type, elapsed_ms, page)
          TimerStruct::Custom.new(type, elapsed_ms, page, self).tap do |timer|
            timer[:parent_timing_id] = self[:id]

            self[:custom_timings][type] ||= []
            self[:custom_timings][type].push(timer)

            self[:custom_timing_stats][type] ||= {:count => 0, :duration => 0.0}
            self[:custom_timing_stats][type][:count]    += 1
            self[:custom_timing_stats][type][:duration] += elapsed_ms

            page[:custom_timing_stats][type] ||= {:count => 0, :duration => 0.0}
            page[:custom_timing_stats][type][:count]    += 1
            page[:custom_timing_stats][type][:duration] += elapsed_ms
          end
        end

        def record_time(milliseconds = nil)
          milliseconds ||= (Time.now - @start) * 1000
          self[:duration_milliseconds]                  = milliseconds
          self[:is_trivial]                             = true if milliseconds < self[:trivial_duration_threshold_milliseconds]
          self[:duration_without_children_milliseconds] = milliseconds - @children_duration

          if @parent
            @parent.children_duration += milliseconds
          end

        end

      end
    end
  end
end
