module Rack
  class MiniProfiler
    module TimerStruct
      class Request < TimerStruct::Base

        def self.createRoot(name, page)
          TimerStruct::Request.new(name, page, nil).tap do |timer|
            timer["IsRoot"] = true
          end
        end

        attr_accessor :children_duration

        def initialize(name, page, parent)
          start_millis = (Time.now.to_f * 1000).to_i - page['Started']
          depth        = parent ? parent.depth + 1 : 0
          super(
            "Id"                                   => MiniProfiler.generate_id,
            "Name"                                 => name,
            "DurationMilliseconds"                 => 0,
            "DurationWithoutChildrenMilliseconds"  => 0,
            "StartMilliseconds"                    => start_millis,
            "ParentTimingId"                       => nil,
            "Children"                             => [],
            "HasChildren"                          => false,
            "KeyValues"                            => nil,
            "HasSqlTimings"                        => false,
            "HasDuplicateSqlTimings"               => false,
            "TrivialDurationThresholdMilliseconds" => 2,
            "SqlTimings"                           => [],
            "SqlTimingsDurationMilliseconds"       => 0,
            "IsTrivial"                            => false,
            "IsRoot"                               => false,
            "Depth"                                => depth,
            "ExecutedReaders"                      => 0,
            "ExecutedScalars"                      => 0,
            "ExecutedNonQueries"                   => 0,
            "CustomTimingStats"                    => {},
            "CustomTimings"                        => {}
          )
          @children_duration = 0
          @start             = Time.now
          @parent            = parent
          @page              = page
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

        def custom_timings
          self['CustomTimings']
        end

        def add_child(name)
          TimerStruct::Request.new(name, @page, self).tap do |timer|
            self['Children'].push(timer)
            self['HasChildren']     = true
            timer['ParentTimingId'] = self['Id']
            timer['Depth']          = self['Depth'] + 1
          end
        end

        def add_sql(query, elapsed_ms, page, skip_backtrace = false, full_backtrace = false)
          TimerStruct::Sql.new(query, elapsed_ms, page, self , skip_backtrace, full_backtrace).tap do |timer|
            self['SqlTimings'].push(timer)
            timer['ParentTimingId'] = self['Id']
            self['HasSqlTimings']   = true
            self['SqlTimingsDurationMilliseconds'] += elapsed_ms
            page['DurationMillisecondsInSql']      += elapsed_ms
          end
        end

        def add_custom(type, elapsed_ms, page)
          TimerStruct::Custom.new(type, elapsed_ms, page, self).tap do |timer|
            timer['ParentTimingId'] = self['Id']

            self['CustomTimings'][type] ||= []
            self['CustomTimings'][type].push(timer)

            self['CustomTimingStats'][type] ||= {"Count" => 0, "Duration" => 0.0}
            self['CustomTimingStats'][type]['Count']    += 1
            self['CustomTimingStats'][type]['Duration'] += elapsed_ms

            page['CustomTimingStats'][type] ||= {"Count" => 0, "Duration" => 0.0}
            page['CustomTimingStats'][type]['Count']    += 1
            page['CustomTimingStats'][type]['Duration'] += elapsed_ms
          end
        end

        def record_time(milliseconds = nil)
          milliseconds ||= (Time.now - @start) * 1000
          self['DurationMilliseconds']                = milliseconds
          self['IsTrivial']                           = true if milliseconds < self["TrivialDurationThresholdMilliseconds"]
          self['DurationWithoutChildrenMilliseconds'] = milliseconds - @children_duration

          if @parent
            @parent.children_duration += milliseconds
          end

        end

      end
    end
  end
end
