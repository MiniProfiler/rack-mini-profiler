require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # PageTimerStruct
    #   Root: RequestTimer
    #     :has_many RequestTimer children
    #     :has_many SqlTimer children
    #     :has_many CustomTimer children
    class PageTimerStruct < TimerStruct
      def initialize(env)
        super(:id => MiniProfiler.generate_id,
              :name => env['PATH_INFO'],
              :started => (Time.now.to_f * 1000).to_i,
              :machineName => env['SERVER_NAME'],
              :level => 0,
              :user => "unknown user",
              :hasUserViewed => false,
              :clientTimings => nil,
              :durationMilliseconds => 0,
              :hasTrivialTimings => true,
              :hasAllTrivialTimigs => false,
              :trivialDurationThresholdMilliseconds => 2,
              :head => nil,
              :durationMillisecondsInSql => 0,
              :hasSqlTimings => true,
              :hasDuplicateSqlTimings => false,
              :executedReaders => 0,
              :executedScalars => 0,
              :executedNonQueries => 0,
              :customTimingNames => [],
              :customTimingStats => {}
             )
        name = "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
        self[:root] = RequestTimerStruct.createRoot(name, self)
      end

      def duration_ms
        @attributes[:root][:durationMilliseconds]
      end

      def root
        @attributes[:root]
      end

      def to_json(*a)
        attribs = @attributes.merge(
          :started => '/Date(%d)/' % @attributes[:started],
          :durationMilliseconds => @attributes[:root][:durationMilliseconds],
          :customTimingNames => @attributes[:customTimingStats].keys.sort
        )
        ::JSON.generate(attribs, :max_nesting => 100)
      end
    end

  end
end
