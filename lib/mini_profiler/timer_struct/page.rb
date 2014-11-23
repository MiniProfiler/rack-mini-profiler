module Rack
  class MiniProfiler
    module TimerStruct

      # TimerStruct::Page
      #   Root: RequestTimer
      #     :has_many RequestTimer children
      #     :has_many SqlTimer children
      #     :has_many CustomTimer children
      class Page < TimerStruct::Base
        def initialize(env)
          timer_id     = MiniProfiler.generate_id
          page_name    = env['PATH_INFO']
          started_at   = (Time.now.to_f * 1000).to_i
          machine_name = env['SERVER_NAME']
          super(
            "Id"                                   => timer_id,
            "Name"                                 => page_name,
            "Started"                              => started_at,
            "MachineName"                          => machine_name,
            "Level"                                => 0,
            "User"                                 => "unknown user",
            "HasUserViewed"                        => false,
            "ClientTimings"                        => nil,
            "DurationMilliseconds"                 => 0,
            "HasTrivialTimings"                    => true,
            "HasAllTrivialTimigs"                  => false,
            "TrivialDurationThresholdMilliseconds" => 2,
            "Head"                                 => nil,
            "DurationMillisecondsInSql"            => 0,
            "HasSqlTimings"                        => true,
            "HasDuplicateSqlTimings"               => false,
            "ExecutedReaders"                      => 0,
            "ExecutedScalars"                      => 0,
            "ExecutedNonQueries"                   => 0,
            "CustomTimingNames"                    => [],
            "CustomTimingStats"                    => {}
          )
          name = "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
          self['Root'] = TimerStruct::Request.createRoot(name, self)
        end

        def duration_ms
          @attributes['Root']['DurationMilliseconds']
        end

        def root
          @attributes['Root']
        end

        def to_json(*a)
          attribs = @attributes.merge(
            "Started"              => '/Date(%d)/' % @attributes['Started'],
            "DurationMilliseconds" => @attributes['Root']['DurationMilliseconds'],
            "CustomTimingNames"    => @attributes['CustomTimingStats'].keys.sort
          )
          ::JSON.generate(attribs, :max_nesting => 100)
        end
      end
    end
  end
end
