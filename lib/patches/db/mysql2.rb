# frozen_string_literal: true

# The best kind of instrumentation is in the actual db provider, however we don't want to double instrument

class Mysql2::Result
  alias_method :each_without_profiling, :each
  def each(*args, &blk)
    unless defined?(@miniprofiler_sql_id)
      return each_without_profiling(*args, &blk)
    end

    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = each_without_profiling(*args, &blk)
    elapsed_time = SqlPatches.elapsed_time(start)

    @miniprofiler_sql_id.report_reader_duration(elapsed_time)
    result
  end
end

class Mysql2::Client
  alias_method :query_without_profiling, :query
  def query(*args, &blk)
    unless SqlPatches.should_measure?
      return query_without_profiling(*args, &blk)
    end

    result, record =
      SqlPatches.record_sql(args[0]) { query_without_profiling(*args, &blk) }
    result.instance_variable_set('@miniprofiler_sql_id', record) if result
    result
  end
end
