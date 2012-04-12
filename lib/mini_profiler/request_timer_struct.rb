require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    class RequestTimerStruct < TimerStruct
      def self.createRoot(name, page)
        rt = RequestTimerStruct.new(name, page)
        rt["IsRoot"]= true
        rt
      end

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
        @attributes['Children'].push(request_timer)
        @attributes['HasChildren'] = true
        request_timer['ParentTimingId'] = @attributes['Id']
        request_timer['Depth'] = @attributes['Depth'] + 1
        @children_duration += request_timer['DurationMilliseconds']
      end

      def add_sql(query, elapsed_ms, page)
        timer = SqlTimerStruct.new(query, elapsed_ms, page)
        timer['ParentTimingId'] = @attributes['Id']
        @attributes['SqlTimings'].push(timer)
        @attributes['HasSqlTimings'] = true
        @attributes['SqlTimingsDurationMilliseconds'] += elapsed_ms
      end

      def record_time(milliseconds)
        @attributes['DurationMilliseconds'] = milliseconds
        @attributes['DurationWithoutChildrenMilliseconds'] = milliseconds - @children_duration
      end     
    end
  end
  
end
