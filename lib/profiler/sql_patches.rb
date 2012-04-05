module SqlPatches
	def self.class_exists?(name)
		eval(name + ".class") == 'Class'
	rescue NameError
		false
	end
end

if SqlPatches.class_exists? "Sequel::Database" then
	module Sequel
		class Database
			alias_method log_duration_original, log_duration
			def log_duration(duration, message)
				MiniProfiler.instance.record_sql(message, duration)
				log_duration_original(duration, message)
			end
		end
	end
end
