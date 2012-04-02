require "benchmark"

module Rack

	class MiniProfiler

		def initialize(app, options={})
			options = {
				:auto => true,	# automatically load on every html page
				:auto_libs => true, # append body with libraries automatically
				:serve_libs => true, # what libraries to server automatically
			}.merge(options)
			@app = app
		end

		def call(env)
			status = headers = body = nil
			env['x-mini_profiler'] = self
			tms = Benchmark.measure do
				status, headers, body = @app.call(env)
			end
			# append results to body
			[status, headers, body]
		end

		def start(label)
			# start sub profile
		end

		def stop
			# ends sub-profile
		end

		def step
			# profile given block
		end
	end

end

