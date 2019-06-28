# frozen_string_literal: true

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
          started      = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i
          machine_name = env['SERVER_NAME']
          super(
            id: timer_id,
            name: page_name,
            started: started,
            started_at: started_at,
            machine_name: machine_name,
            level: 0,
            user: "unknown user",
            has_user_viewed: false,
            client_timings: nil,
            duration_milliseconds: 0,
            has_trivial_timings: true,
            has_all_trivial_timings: false,
            trivial_duration_threshold_milliseconds: 2,
            head: nil,
            sql_count: 0,
            duration_milliseconds_in_sql: 0,
            has_sql_timings: true,
            has_duplicate_sql_timings: false,
            executed_readers: 0,
            executed_scalars: 0,
            executed_non_queries: 0,
            custom_timing_names: [],
            custom_timing_stats: {}
          )
          name = "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
          self[:root] = TimerStruct::Request.createRoot(name, self)
        end

        def name
          @attributes[:name]
        end

        def duration_ms
          @attributes[:root][:duration_milliseconds]
        end

        def duration_ms_in_sql
          @attributes[:duration_milliseconds_in_sql]
        end

        def root
          @attributes[:root]
        end

        def to_json(*a)
          ::JSON.generate(@attributes.merge(self.extra_json))
        end

        def as_json(options = nil)
          super(options).merge!(extra_json)
        end

        def extra_json
          {
            started: '/Date(%d)/' % @attributes[:started_at],
            duration_milliseconds: @attributes[:root][:duration_milliseconds],
            custom_timing_names: @attributes[:custom_timing_stats].keys.sort
          }
        end
      end
    end
  end
end
