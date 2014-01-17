require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    class RequestTimerStruct < TimerStruct

      def self.create_root(name, page)
        rt = RequestTimerStruct.new(name, page, nil)
        rt[:isRoot]= true
        rt
      end

      attr_accessor :children_duration

      def initialize(name, page, parent)
        super(:id => MiniProfiler.generate_id,
              :name => name,
              :duration_milliseconds => 0,
              :duration_without_children_milliseconds => 0,
              :start_milliseconds => (Time.now.to_f * 1000).to_i - page[:started],
              :parent_timing_id => nil,
              :children => [],
              :has_children => false,
              :key_values => nil,
              :has_sql_timings => false,
              :has_duplicate_sql_timings => false,
              :trivial_duration_threshold_milliseconds => 2,
              :sql_timings => [],
              :sql_timings_duration_milliseconds => 0,
              :is_trivial => false,
              :is_root => false,
              :depth => parent ? parent.depth + 1 : 0,
              :executed_readers => 0,
              :executed_scalars => 0,
              :executed_non_queries => 0,
              :custom_timing_stats => {},
              :custom_timings => {})
        @children_duration = 0
        @start = Time.now
        @parent = parent
        @page = page
      end

      def duration_ms
        self[:duration_milliseconds]
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

      def add_child(name)
        request_timer =  RequestTimerStruct.new(name, @page, self)
        self[:children].push(request_timer)
        self[:has_children] = true
        request_timer[:parent_timing_id] = self[:id]
        request_timer[:depth] = self[:depth] + 1
        request_timer
      end

      def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
        timer = SqlTimerStruct.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace)
        timer[:parent_timing_id] = self[:id]
        self[:sql_timings].push(timer)
        self[:has_sql_timings] = true
        self[:sql_timings_duration_milliseconds] += elapsed_ms
        page[:duration_milliseconds_in_sql] += elapsed_ms
        timer
      end

      def add_custom(type, elapsed_ms, page)
        timer = CustomTimerStruct.new(type, elapsed_ms, page, self)
        timer[:parent_timing_id] = self[:id]
        self[:custom_timings][type] ||= []
        self[:custom_timings][type].push(timer)

        self[:custom_timing_stats][type] ||= {:count => 0, :duration => 0.0}
        self[:custom_timing_stats][type][:count] += 1
        self[:custom_timing_stats][type][:duration] += elapsed_ms

        page[:custom_timing_stats][type] ||= {:count => 0, :duration => 0.0}
        page[:custom_timing_stats][type][:count] += 1
        page[:custom_timing_stats][type][:duration] += elapsed_ms

        timer
      end

      def record_time(milliseconds = nil)
        milliseconds ||= (Time.now - @start) * 1000
        self[:duration_milliseconds] = milliseconds
        self[:is_trivial] = true if milliseconds < self[:trivial_duration_threshold_milliseconds]
        self[:duration_without_children_milliseconds] = milliseconds - @children_duration

        if @parent
          @parent.children_duration += milliseconds
        end

      end
    end
  end

end
