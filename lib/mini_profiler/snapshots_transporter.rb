# frozen_string_literal: true

class ::Rack::MiniProfiler::SnapshotsTransporter
  @@transported_snapshots_count = 0
  @@successful_http_requests_count = 0
  @@failed_http_requests_count = 0

  class << self
    def transported_snapshots_count
      @@transported_snapshots_count
    end
    def successful_http_requests_count
      @@successful_http_requests_count
    end
    def failed_http_requests_count
      @@failed_http_requests_count
    end

    def transport(snapshot)
      @transporter ||= self.new(Rack::MiniProfiler.config)
      @transporter.ship(snapshot)
    end
  end

  attr_reader :buffer
  attr_accessor :max_buffer_size

  def initialize(config)
    @uri = URI(config.snapshots_transport_destination_url)
    @auth_key = config.snapshots_transport_auth_key
    @thread = nil
    @thread_mutex = Mutex.new
    @buffer = []
    @buffer_mutex = Mutex.new
    @max_buffer_size = 100
    @testing = false
  end

  def ship(snapshot)
    @buffer_mutex.synchronize do
      @buffer << snapshot
      @buffer.shift if @buffer.size > @max_buffer_size
    end
    @thread_mutex.synchronize { start_thread }
  end

  def flush_buffer
    buffer_content = @buffer_mutex.synchronize do
      @buffer.dup if @buffer.size > 0
    end
    if buffer_content
      request = Net::HTTP::Post.new(
        @uri,
        'Content-Type' => 'application/json',
        'Mini-Profiler-Transport-Auth' => @auth_key
      )
      request.body = { snapshots: buffer_content }.to_json
      http = Net::HTTP.new(@uri.hostname, @uri.port)
      http.use_ssl = @uri.scheme == 'https'
      res = http.request(request)
      if res.code.to_i == 200
        @@successful_http_requests_count += 1
        @@transported_snapshots_count += buffer_content.size
        @buffer_mutex.synchronize do
          @buffer -= buffer_content
        end
      else
        @@failed_http_requests_count += 1
      end
    end
  end

  private

  def start_thread
    return if @thread&.alive? || @testing
    @thread = Thread.new do
      while true
        sleep 10
        flush_buffer
      end
    end
  end
end
