module Rack
  class MiniProfiler
    class ActiveRecordLogger
      def call(name, start_time, finish_time, id, payload)
        if SqlPatches.should_measure? && !ignore_payload?(payload)
          elapsed_time = ((finish_time.to_f - start_time.to_f) * 1000).round(1)
          if name == "sql.active_record"
            Rack::MiniProfiler.record_sql(payload[:sql], elapsed_time, binds_to_params(payload[:binds]))
          elsif name == 'instantiation.active_record'
            Rack::MiniProfiler.report_reader_duration(elapsed_time, payload[:record_count], payload[:class_name])
          end
        end
      end

      def binds_to_params(binds)
        return if binds.nil? || Rack::MiniProfiler.config.max_sql_param_length == 0
        # map ActiveRecord::Relation::QueryAttribute to [name, value]
        params = binds.map { |c| c.kind_of?(Array) ? [c.first, c.last] : [c.name, c.value] }
        if (skip = Rack::MiniProfiler.config.skip_sql_param_names)
          params.map { |(n,v)| n =~ skip ? [n, nil] : [n, v] }
        else
          params
        end
      end

      # ORACLE and PG query types
      # both use nil for schema queries and non schema queries
      SCHEMA_QUERY_TYPES = ["Sequence", "Primary Key", "Primary Key Trigger", "SCHEMA"].freeze

      IGNORED_PAYLOAD=%w(EXPLAIN CACHE)
      def ignore_payload?(payload)
        payload[:exception] ||
        (Rack::MiniProfiler.config.skip_schema_queries and SCHEMA_QUERY_TYPES.include?(payload[:name])) ||
        %w(EXPLAIN CACHE).include?(payload[:name])
      end
    end

    def self.subscribe_sql_notifications
      logger = ::Rack::MiniProfiler::ActiveRecordLogger.new
      %w(sql.active_record instantiation.active_record).each do |event|
        ActiveSupport::Notifications.subscribe(event, logger)
      end
    end
  end
end

::Rack::MiniProfiler.subscribe_sql_notifications
