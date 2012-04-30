module SqlPatches
	def self.class_exists?(name)
		eval(name + ".class").to_s.eql?('Class')
	rescue NameError
		false
	end
end

if SqlPatches.class_exists? "Sequel::Database" then
	module Sequel
		class Database
			alias_method :log_duration_original, :log_duration
			def log_duration(duration, message)
				::Rack::MiniProfiler.instance.record_sql(message, duration) if ::Rack::MiniProfiler.instance
				log_duration_original(duration, message)
			end
		end
	end
end


## based off https://github.com/newrelic/rpm/blob/master/lib/new_relic/agent/instrumentation/active_record.rb
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
        sql, name, binds = args
        t0 = Time.now
        rval = log_without_miniprofiler(*args, &block)

        # Get our MP Instance
        instance = ::Rack::MiniProfiler.instance
        return rval unless instance

        # Don't log schema queries if the option is set
        return rval if instance.options[:skip_schema_queries] and name =~ /SCHEMA/

        elapsed_time = ((Time.now - t0).to_f * 1000).to_i
        instance.record_sql(sql, elapsed_time)
        rval
      end
    end
  end

  def self.insert_instrumentation 
    ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval do
      include ::Rack::MiniProfiler::ActiveRecordInstrumentation
    end
  end

  if defined?(::Rails)
    if ::Rails::VERSION::MAJOR.to_i == 3
    # in theory this is the right thing to do for rails 3 ... but it seems to work anyway
    #Rails.configuration.after_initialize do
        insert_instrumentation
    #end
    else
      insert_instrumentation
    end
  end
end

