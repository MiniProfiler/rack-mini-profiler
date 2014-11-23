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
          return log_without_miniprofiler(*args, &block) unless current && current.measure

          sql, name, binds = args
          start            = Time.now
          rval             = log_without_miniprofiler(*args, &block)

          # Don't log schema queries if the option is set
          return rval if Rack::MiniProfiler.config.skip_schema_queries and name =~ /SCHEMA/

          elapsed_time = ((Time.now - start).to_f * 1000).round(1)
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
