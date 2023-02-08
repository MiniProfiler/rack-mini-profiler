# frozen_string_literal: true

require "mysql2"

class Mysql2::Result
  module MiniProfiler
    def each(*args, &blk)
      return super unless defined?(@miniprofiler_sql_id)

      start        = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result       = super
      elapsed_time = Rack::MiniProfiler::Sql.elapsed_time(start)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end
  end

  prepend MiniProfiler
end

class Mysql2::Client
  module MiniProfiler
    def query(*args, &blk)
      return super unless Rack::MiniProfiler::Sql.should_measure?

      result, record = Rack::MiniProfiler::Sql.record_sql(args[0]) do
        super
      end
      result.instance_variable_set("@miniprofiler_sql_id", record) if result
      result
    end
  end

  prepend MiniProfiler
end
