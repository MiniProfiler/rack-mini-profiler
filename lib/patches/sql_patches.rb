class SqlPatches

  def self.patched?
    @patched
  end

  def self.patched=(val)
    @patched = val
  end

  def self.class_exists?(name)
    eval(name + ".class").to_s.eql?('Class')
  rescue NameError
    false
  end

  def self.module_exists?(name)
    eval(name + ".class").to_s.eql?('Module')
  rescue NameError
    false
  end
end

# The best kind of instrumentation is in the actual db provider, however we don't want to double instrument
if SqlPatches.class_exists? "Mysql2::Client"

  class Mysql2::Result
    alias_method :each_without_profiling, :each
    def each(*args, &blk)
      return each_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start = Time.now
      result = each_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end
  end

  class Mysql2::Client
    alias_method :query_without_profiling, :query
    def query(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return query_without_profiling(*args,&blk) unless current

      start = Time.now
      result = query_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(args[0], elapsed_time))

      result

    end
  end

  SqlPatches.patched = true
end


# PG patches, keep in mind exec and async_exec have a exec{|r| } semantics that is yet to be implemented
if SqlPatches.class_exists? "PG::Result"

  class PG::Result
    alias_method :each_without_profiling, :each
    alias_method :values_without_profiling, :values

    def values(*args, &blk)
      return values_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start = Time.now
      result = values_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      @miniprofiler_sql_id.report_reader_duration(elapsed_time)
      result
    end

    def each(*args, &blk)
      return each_without_profiling(*args, &blk) unless @miniprofiler_sql_id

      start = Time.now
      result = each_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

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

      current = ::Rack::MiniProfiler.current
      return prepare_without_profiling(*args,&blk) unless current

      prepare_without_profiling(*args,&blk)
    end

    def exec(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_without_profiling(*args,&blk) unless current

      start = Time.now
      result = exec_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(args[0], elapsed_time))

      result
    end

    def exec_prepared(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_prepared_without_profiling(*args,&blk) unless current

      start = Time.now
      result = exec_prepared_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      mapped = args[0]
      mapped = @prepare_map[mapped] || args[0] if @prepare_map
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(mapped, elapsed_time))

      result
    end

    def send_query_prepared(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return send_query_prepared_without_profiling(*args,&blk) unless current

      start = Time.now
      result = send_query_prepared_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      mapped = args[0]
      mapped = @prepare_map[mapped] || args[0] if @prepare_map
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(mapped, elapsed_time))

      result
    end

    def async_exec(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return exec_without_profiling(*args,&blk) unless current

      start = Time.now
      result = exec_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(args[0], elapsed_time))

      result
    end

    alias_method :query, :exec
  end

  SqlPatches.patched = true
end


# Mongoid 3 patches
if SqlPatches.class_exists?("Moped::Node")
  class Moped::Node
    alias_method :process_without_profiling, :process
    def process(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return process_without_profiling(*args,&blk) unless current

      start = Time.now
      result = process_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(args[0].log_inspect, elapsed_time))

      result
    end
  end
end

if SqlPatches.class_exists?("RSolr::Connection") && RSolr::VERSION[0] != "0" #  requires at least v1.0.0
  class RSolr::Connection
    alias_method :execute_without_profiling, :execute
    def execute_with_profiling(client, request_context)
      current = ::Rack::MiniProfiler.current
      return execute_without_profiling(client, request_context) unless current

      start = Time.now
      result = execute_without_profiling(client, request_context)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)

      data = "#{request_context[:method].upcase} #{request_context[:uri]}"
      if request_context[:method] == :post and request_context[:data]
        data << "\n#{Rack::Utils.unescape(request_context[:data])}"
      end
      result.instance_variable_set("@miniprofiler_sql_id", ::Rack::MiniProfiler.record_sql(data, elapsed_time))

      result
    end
    alias_method :execute, :execute_with_profiling
  end
end


# Fallback for sequel
if SqlPatches.class_exists?("Sequel::Database") && !SqlPatches.patched?
  module Sequel
    class Database
      alias_method :log_duration_original, :log_duration
      def log_duration(duration, message)
        ::Rack::MiniProfiler.record_sql(message, duration)
        log_duration_original(duration, message)
      end
    end
  end
end


## based off https://github.com/newrelic/rpm/blob/master/lib/new_relic/agent/instrumentation/active_record.rb
## fallback for alls sorts of weird dbs
if SqlPatches.module_exists?('ActiveRecord') && !SqlPatches.patched?
  module Rack
    class MiniProfiler
      module ActiveRecordInstrumentation
        def self.included(instrumented_class)
          instrumented_class.class_eval do
            unless instrumented_class.method_defined?(:log_without_miniprofiler)
              alias_method :log_without_miniprofiler, :log
              alias_method :log, :log_with_miniprofiler
              protected :log
            end
          end
        end

        def log_with_miniprofiler(*args, &block)
          current = ::Rack::MiniProfiler.current
          return log_without_miniprofiler(*args, &block) unless current

          sql, name, binds = args
          t0 = Time.now
          rval = log_without_miniprofiler(*args, &block)

          # Don't log schema queries if the option is set
          return rval if Rack::MiniProfiler.config.skip_schema_queries and name =~ /SCHEMA/

          elapsed_time = ((Time.now - t0).to_f * 1000).round(1)
          Rack::MiniProfiler.record_sql(sql, elapsed_time)
          rval
        end
      end
    end

    def self.insert_instrumentation
      ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval do
        include ::Rack::MiniProfiler::ActiveRecordInstrumentation
      end
    end

    if defined?(::Rails) && !SqlPatches.patched?
      insert_instrumentation
    end
  end
end
