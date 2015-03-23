module Rack
  class MiniProfiler
    module TimerStruct

      # TimerStruct::Page
      #   Root: TimerStruct::Request
      #     :has_many TimerStruct::Request children
      #     :has_many TimerStruct::Sql children
      #     :has_many TimerStruct::Custom children
      class Page < TimerStruct::Base
        def initialize(env)
          timer_id     = MiniProfiler.generate_id
          page_name    = env['PATH_INFO']
          started_at   = (Time.now.to_f * 1000).to_i
          machine_name = env['SERVER_NAME']
          super(
            :Id                                      => timer_id,
            :Name                                    => page_name,
            :Started                                 => started_at,
            :MachineName                             => machine_name,
            :User                                    => "unknown user",
            :has_user_viewed                         => false,
            :ClientTimings                           => nil,
            :DurationMilliseconds                    => 0,
            :HasTrivialTimings                       => true,
            :trivial_duration_threshold_milliseconds => 2,
            :head                                    => nil,
            :duration_milliseconds_in_sql            => 0,
            :has_sql_timings                         => true,
            :has_duplicate_sql_timings               => false,
            :executed_readers                        => 0,
            :executed_scalars                        => 0,
            :executed_non_queries                    => 0,
            :custom_timing_names                     => [],
            :custom_timing_stats                     => {}
          )
          name = "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
          self[:Root] = TimerStruct::Request.createRoot(name, self)
        end

        def duration_ms
          root[:DurationMilliseconds]
        end

        def root
          @attributes[:Root]
        end

        def to_json(*a)
          attribs = @attributes.merge(
            :Started               => '/Date(%d)/' % @attributes[:Started],
            :DurationMilliseconds => duration_ms,
            :custom_timing_names   => @attributes[:custom_timing_stats].keys.sort
          )
          ::JSON.generate(attribs, :max_nesting => 100)
        end
      end
    end
  end
end
