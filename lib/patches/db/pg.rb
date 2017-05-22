# PG patches, keep in mind exec and async_exec have a exec{|r| } semantics that is yet to be implemented
class PG::Result
  alias_method :each_without_profiling, :each
  alias_method :values_without_profiling, :values

  def values(*args, &blk)
    return values_without_profiling(*args, &blk) unless defined?(@miniprofiler_sql_id)
    mp_report_sql do
      values_without_profiling(*args ,&blk)
    end
  end

  def each(*args, &blk)
    return each_without_profiling(*args, &blk) unless defined?(@miniprofiler_sql_id)
    mp_report_sql do
      each_without_profiling(*args, &blk)
    end
  end

  def mp_report_sql(&block)
    start        = Time.now
    result       = yield
    elapsed_time = SqlPatches.elapsed_time(start)
    @miniprofiler_sql_id.report_reader_duration(elapsed_time)
    result
  end
end

class PG::Connection
  alias_method :exec_without_profiling, :exec
  alias_method :async_exec_without_profiling, :async_exec
  alias_method :exec_prepared_without_profiling, :exec_prepared
  alias_method :send_query_prepared_without_profiling, :send_query_prepared
  alias_method :prepare_without_profiling, :prepare

  def prepare(*args,&blk)
    # we have no choice but to do this here,
    # if we do the check for profiling first, our cache may miss critical stuff

    @prepare_map ||= {}
    @prepare_map[args[0]] = args[1]
    # dont leak more than 10k ever
    @prepare_map = {} if @prepare_map.length > 1000

    return prepare_without_profiling(*args,&blk) unless SqlPatches.should_measure?
    prepare_without_profiling(*args,&blk)
  end

  def exec(*args,&blk)
    return exec_without_profiling(*args,&blk) unless SqlPatches.should_measure?

    start        = Time.now
    result       = exec_without_profiling(*args,&blk)
    elapsed_time = SqlPatches.elapsed_time(start)
    record       = ::Rack::MiniProfiler.record_sql(args[0], elapsed_time, get_binds(*args))
    result.instance_variable_set("@miniprofiler_sql_id", record) if result

    result
  end

  def exec_prepared(*args,&blk)
    return exec_prepared_without_profiling(*args,&blk) unless SqlPatches.should_measure?

    start        = Time.now
    result       = exec_prepared_without_profiling(*args,&blk)
    elapsed_time = SqlPatches.elapsed_time(start)
    mapped       = args[0]
    mapped       = @prepare_map[mapped] || args[0] if @prepare_map
    record       = ::Rack::MiniProfiler.record_sql(mapped, elapsed_time, get_binds(mapped, args[1]))
    result.instance_variable_set("@miniprofiler_sql_id", record) if result

    result
  end

  def send_query_prepared(*args,&blk)
    return send_query_prepared_without_profiling(*args,&blk) unless SqlPatches.should_measure?

    start        = Time.now
    result       = send_query_prepared_without_profiling(*args,&blk)
    elapsed_time = SqlPatches.elapsed_time(start)
    mapped       = args[0]
    mapped       = @prepare_map[mapped] || args[0] if @prepare_map
    record       = ::Rack::MiniProfiler.record_sql(mapped, elapsed_time, get_binds(mapped, args[1]))
    result.instance_variable_set("@miniprofiler_sql_id", record) if result

    result
  end

  def async_exec(*args,&blk)
    return async_exec_without_profiling(*args,&blk) unless SqlPatches.should_measure?

    start        = Time.now
    result       = exec_without_profiling(*args,&blk)
    elapsed_time = SqlPatches.elapsed_time(start)
    record       = ::Rack::MiniProfiler.record_sql(args[0], elapsed_time, get_binds(*args))
    result.instance_variable_set("@miniprofiler_sql_id", record) if result

    result
  end

  def get_binds(*args)
    params = args[1]
    return if params.nil? || params.empty?

    sql = args[0]
    arr = nil

    if sql.match(/\(\$\d/)
      # regular selects list of names from sql query, for ex. ("name1", "name2", "name3")
      arr = sql.match(/\((\"\w+\",?\s?)+\)/).to_s.gsub!(/[",()]/, '').to_s.split
    end

    if arr.nil? || arr.empty?
      params.each_with_index.inject({}) do |hash, (param, i)|
        # regular selects param name from sql query, like for ex. "name1" = $1
        key = sql.match(/[^\s\.]+\s?=?\s\$#{i+1}/).to_s.split[0]
        key.gsub!(/["]/, '') if key
        hash.merge(key => param)
      end
    else
      Hash[arr.zip(params)]
    end
  end

  alias_method :query, :exec
end
