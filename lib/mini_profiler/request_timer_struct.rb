require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    class RequestTimerStruct < TimerStruct

      def self.createRoot(name, page)
        rt = RequestTimerStruct.new(name, page, nil)
        rt["IsRoot"]= true
        rt
      end

      attr_accessor :children_duration

      def initialize(name, page, parent)
        super("Id" => MiniProfiler.generate_id,
              "Name" => name,
              "DurationMilliseconds" => 0,
              "DurationWithoutChildrenMilliseconds"=> 0,
              "StartMilliseconds" => (Time.now.to_f * 1000).to_i - page['Started'],
              "ParentTimingId" => nil,
              "Children" => [],
              "HasChildren"=> false,
              "KeyValues" => nil,
              "HasSqlTimings"=> false,
              "HasWebServiceTimings"=> false,
              "HasDuplicateSqlTimings"=> false,
              "TrivialDurationThresholdMilliseconds" => 2,
              "SqlTimings" => [],
              "WebServiceTimings" => [],
              "SqlTimingsDurationMilliseconds"=> 0,
              "WebServiceTimingsDurationMilliseconds"=> 0,
              "IsTrivial"=> false,
              "IsRoot"=> false,
              "Depth"=> parent ? parent.depth + 1 : 0,
              "ExecutedReaders"=> 0,
              "ExecutedScalars"=> 0,
              "ExecutedNonQueries"=> 0,
              "CustomTimingStats" => {},
              "CustomTimings" => {})
        @children_duration = 0
        @start = Time.now
        @parent = parent
        @page = page
      end

      def duration_ms
        self['DurationMilliseconds']
      end

      def start_ms
        self['StartMilliseconds']
      end

      def start
        @start
      end

      def depth
        self['Depth']
      end

      def children
        self['Children']
      end

      def add_child(name)
        request_timer =  RequestTimerStruct.new(name, @page, self)
        self['Children'].push(request_timer)
        self['HasChildren'] = true
        request_timer['ParentTimingId'] = self['Id']
        request_timer['Depth'] = self['Depth'] + 1
        request_timer
      end

      def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
        timer = SqlTimerStruct.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace)
        timer['ParentTimingId'] = self['Id']
        self['SqlTimings'].push(timer)
        self['HasSqlTimings'] = true
        self['SqlTimingsDurationMilliseconds'] += elapsed_ms
        page['DurationMillisecondsInSql'] += elapsed_ms
        timer
      end

      def add_web_service(name, request, response, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
        timer = WebServiceTimerStruct.new(name, request, response, elapsed_ms, page, self)
        timer['ParentTimingId'] = self['Id']
        self['WebServiceTimings'].push(timer)
        self['HasWebServiceTimings'] = true
        self['WebServiceTimingsDurationMilliseconds'] += elapsed_ms
        page['DurationMillisecondsInWebService'] += elapsed_ms
        timer
      end

      def add_custom(type, elapsed_ms, page)
        timer = CustomTimerStruct.new(type, elapsed_ms, page, self)
        timer['ParentTimingId'] = self['Id']
        self['CustomTimings'][type] ||= []
        self['CustomTimings'][type].push(timer)

        self['CustomTimingStats'][type] ||= {"Count" => 0, "Duration" => 0.0}
        self['CustomTimingStats'][type]['Count'] += 1
        self['CustomTimingStats'][type]['Duration'] += elapsed_ms

        page['CustomTimingStats'][type] ||= {"Count" => 0, "Duration" => 0.0}
        page['CustomTimingStats'][type]['Count'] += 1
        page['CustomTimingStats'][type]['Duration'] += elapsed_ms

        timer
      end

      def record_time(milliseconds = nil)
        milliseconds ||= (Time.now - @start) * 1000
        self['DurationMilliseconds'] = milliseconds
        self['IsTrivial'] = true if milliseconds < self["TrivialDurationThresholdMilliseconds"]
        self['DurationWithoutChildrenMilliseconds'] = milliseconds - @children_duration

        if @parent
          @parent.children_duration += milliseconds
        end

      end
    end
  end

end
