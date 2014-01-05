require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    class RequestTimerStruct < TimerStruct

      def self.createRoot(name, page)
        rt = RequestTimerStruct.new(name, page, nil)
        rt[:isRoot]= true
        rt
      end

      attr_accessor :children_duration

      def initialize(name, page, parent)
        super(:id => MiniProfiler.generate_id,
              :name => name,
              :durationMilliseconds => 0,
              :durationWithoutChildrenMilliseconds => 0,
              :startMilliseconds => (Time.now.to_f * 1000).to_i - page[:started],
              :parentTimingId => nil,
              :children => [],
              :hasChildren => false,
              :keyValues => nil,
              :hasSqlTimings => false,
              :hasDuplicateSqlTimings => false,
              :trivialDurationThresholdMilliseconds => 2,
              :sqlTimings => [],
              :sqlTimingsDurationMilliseconds => 0,
              :isTrivial => false,
              :isRoot => false,
              :depth => parent ? parent.depth + 1 : 0,
              :executedReaders => 0,
              :executedScalars => 0,
              :executedNonQueries => 0,
              :customTimingStats => {},
              :customTimings => {})
        @children_duration = 0
        @start = Time.now
        @parent = parent
        @page = page
      end

      def duration_ms
        self[:durationMilliseconds]
      end

      def start_ms
        self[:startMilliseconds]
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
        self[:hasChildren] = true
        request_timer[:parentTimingId] = self[:id]
        request_timer[:depth] = self[:depth] + 1
        request_timer
      end

      def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
        timer = SqlTimerStruct.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace)
        timer[:parentTimingId] = self[:id]
        self[:sqlTimings].push(timer)
        self[:hasSqlTimings] = true
        self[:sqlTimingsDurationMilliseconds] += elapsed_ms
        page[:durationMillisecondsInSql] += elapsed_ms
        timer
      end

      def add_custom(type, elapsed_ms, page)
        timer = CustomTimerStruct.new(type, elapsed_ms, page, self)
        timer[:parentTimingId] = self[:id]
        self[:customTimings][type] ||= []
        self[:customTimings][type].push(timer)

        self[:customTimingStats][type] ||= {:count => 0, :duration => 0.0}
        self[:customTimingStats][type][:count] += 1
        self[:customTimingStats][type][:duration] += elapsed_ms

        page[:customTimingStats][type] ||= {:count => 0, :duration => 0.0}
        page[:customTimingStats][type][:count] += 1
        page[:customTimingStats][type][:duration] += elapsed_ms

        timer
      end

      def record_time(milliseconds = nil)
        milliseconds ||= (Time.now - @start) * 1000
        self[:durationMilliseconds] = milliseconds
        self[:isTrivial] = true if milliseconds < self[:trivialDurationThresholdMilliseconds]
        self[:durationWithoutChildrenMilliseconds] = milliseconds - @children_duration

        if @parent
          @parent.children_duration += milliseconds
        end

      end
    end
  end

end
