# frozen_string_literal: true

if (defined?(Net) && defined?(Net::HTTP))

  if defined?(Rack::MINI_PROFILER_PREPEND_NET_HTTP_PATCH)
    module NetHTTPWithMiniProfiler
      def connect()
        if proxy? then
          conn_addr = proxy_address
          conn_port = proxy_port
        else
          conn_addr = conn_address
          conn_port = port
        end
        Rack::MiniProfiler.step("Net::HTTP Connect #{conn_addr}:#{conn_port}") do
          super
        end
      end
      def request(request, *args, &block)
        Rack::MiniProfiler.step("Net::HTTP #{request.method} #{request.path}") do
          super
        end
      end
    end
    Net::HTTP.prepend(NetHTTPWithMiniProfiler)
  else
    Net::HTTP.class_eval do
      def connect_with_mini_profiler()
        if proxy? then
          conn_addr = proxy_address
          conn_port = proxy_port
        else
          conn_addr = conn_address
          conn_port = port
        end
        Rack::MiniProfiler.step("Net::HTTP Connect #{conn_addr}:#{conn_port}") do
          connect_without_mini_profiler()
        end
      end
      alias connect_without_mini_profiler connect
      alias connect connect_with_mini_profiler
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
end
