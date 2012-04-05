module SqlPatches
	def self.class_exists?(name)
		eval(name + ".class").to_s.eql?('Class')
	rescue NameError
		false
	end
end

if SqlPatches.class_exists? "Sequel::Database" then
	puts "Patching Sequel"
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
