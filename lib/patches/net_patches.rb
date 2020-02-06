# frozen_string_literal: true

if (defined?(Net) && defined?(Net::HTTP))
  module NetHTTPWithMiniProfiler
    def request(request, *args, &block)
      Rack::MiniProfiler.step("Net::HTTP #{request.method} #{request.path}") do
        super
      end
    end
  end

  Net::HTTP.prepend(NetHTTPWithMiniProfiler)
end
