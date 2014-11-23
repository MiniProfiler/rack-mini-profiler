# The best kind of instrumentation is in the actual db provider, however we don't want to double instrument
if SqlPatches.class_exists? "Mysql2::Client"

  class Mysql2::Result
    alias_method :each_without_profiling, :each
    def each(*args, &blk)
      return each_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start        = Time.now
      result       = each_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end
  end

  class Mysql2::Client
    alias_method :query_without_profiling, :query
    def query(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return query_without_profiling(*args,&blk) unless current && current.measure

      start        = Time.now
      result       = query_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      record       = ::Rack::MiniProfiler.record_sql(args[0], elapsed_time)
      result.instance_variable_set("@miniprofiler_sql_id", record) if result

      result
    end
  end

  SqlPatches.patched = true
end
