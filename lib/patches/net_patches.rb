# frozen_string_literal: true

if (defined?(Net) && defined?(Net::HTTP))

  Net::HTTP.class_eval do
    def request_with_mini_profiler(*args, &block)
      request = args[0]
      Rack::MiniProfiler.step("Net::HTTP #{request.method} #{request.path}") do
        request_without_mini_profiler(*args, &block)
      end
    end
    alias request_without_mini_profiler request
    alias request request_with_mini_profiler
  end

end
