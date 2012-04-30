require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    class RequestTimerStruct < TimerStruct
      
      def self.createRoot(name, page)
        rt = RequestTimerStruct.new(name, page)
        rt["IsRoot"]= true
        rt
      end

      attr_reader :children_duration

      def initialize(name, page)
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
              "HasDuplicateSqlTimings"=> false,
              "TrivialDurationThresholdMilliseconds" => 2,
              "SqlTimings" => [],
              "SqlTimingsDurationMilliseconds"=> 0,
              "IsTrivial"=> false,
              "IsRoot"=> false,
              "Depth"=> 0,
              "ExecutedReaders"=> 0,
              "ExecutedScalars"=> 0,
              "ExecutedNonQueries"=> 0)
        @children_duration = 0
      end

      def add_child(request_timer)
        self['Children'].push(request_timer)
        self['HasChildren'] = true
        request_timer['ParentTimingId'] = self['Id']
        request_timer['Depth'] = self['Depth'] + 1
        @children_duration += request_timer['DurationMilliseconds']
      end

      def add_sql(query, elapsed_ms, page)
        timer = SqlTimerStruct.new(query, elapsed_ms, page)
        timer['ParentTimingId'] = self['Id']
        self['SqlTimings'].push(timer)
        self['HasSqlTimings'] = true
        self['SqlTimingsDurationMilliseconds'] += elapsed_ms
        page['DurationMillisecondsInSql'] += elapsed_ms        
      end

      def record_time(milliseconds)
        self['DurationMilliseconds'] = milliseconds
        self['IsTrivial'] = true if milliseconds < self["TrivialDurationThresholdMilliseconds"]
        self['DurationWithoutChildrenMilliseconds'] = milliseconds - @children_duration
      end     
    end
  end
  
end
