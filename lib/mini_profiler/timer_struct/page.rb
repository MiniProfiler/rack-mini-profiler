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
            :Id                    => timer_id,
            :Name                  => page_name,
            :Started               => started_at,
            :DurationMilliseconds  => 0,
            :MachineName           => machine_name,
            :ClientTimings         => nil,
            :User                  => "unknown user",
            :has_user_viewed       => false
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
            :DurationMilliseconds => duration_ms
          )
          ::JSON.generate(attribs, :max_nesting => 100)
        end
      end
    end
  end
end
