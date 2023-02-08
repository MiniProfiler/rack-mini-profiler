# frozen_string_literal: true

module Rack
  class MiniProfiler
    module Sql
      class << self
        def record_sql(statement, parameters = nil, &block)
          start  = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          result = yield
          record = ::Rack::MiniProfiler.record_sql(statement, elapsed_time(start), parameters)
          [result, record]
        end

        def should_measure?
          current = ::Rack::MiniProfiler.current
          (current && current.measure)
        end

        def elapsed_time(start_time)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).to_f * 1000).round(1)
        end
      end
    end
  end
end
