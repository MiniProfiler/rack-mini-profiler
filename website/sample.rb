# frozen_string_literal: true

require 'stackprof'
require 'rack-mini-profiler'
require 'sinatra'
require 'sinatra/base'

class SampleStorage < Rack::MiniProfiler::AbstractStore
  def initialize(args)
    @multipliers = [10, 100, 1000]
    @time_units = [1, 60, 3600, 3600 * 24]
    @time_multipliers = (1..60).to_a
  end

  def load(*args)
    return @page_struct if @page_struct
    @data = JSON.parse(File.read(File.expand_path("data.json", __dir__)), symbolize_names: true)
    @page_struct = Rack::MiniProfiler::TimerStruct::Page.allocate
    @page_struct.instance_variable_set(:@attributes, @data)
    @page_struct
  end
  alias_method :load_snapshot, :load

  def save(*args)
  end

  def set_unviewed(*args)
  end

  def get_unviewed_ids(*args)
  end

  def fetch_snapshots_overview
    overview = {}
    snapshots.shuffle.each do |ss|
      group_name = "#{ss[:request_method]} #{ss[:request_path]}"
      group = overview[group_name]
      if group
        group[:worst_score] = ss.duration_ms if ss.duration_ms > group[:worst_score]
        group[:best_score] = ss.duration_ms if ss.duration_ms < group[:best_score]
        group[:snapshots_count] += 1
      else
        overview[group_name] = {
          worst_score: ss.duration_ms,
          best_score: ss.duration_ms,
          snapshots_count: 1
        }
      end
    end
    overview
  end

  def fetch_snapshots_group(group_name)
    snapshots.select do |snapshot|
      group_name == "#{snapshot[:request_method]} #{snapshot[:request_path]}"
    end
  end

  private

  def snapshots
    return @snapshots if @snapshots
    methods = %w[POST GET DELETE PUT PATCH]
    paths = %w[
      topics#index
      topics#update
      topics#delete
      users#delete
      users#update
      users#index
      /some/fairly/long/path/here
    ]
    @snapshots = methods.product(paths).map do |method, path|
      create_fake_snapshot(
        methods.sample,
        paths.sample,
        SecureRandom.rand * @multipliers.sample,
        ((Time.now.to_f - @time_units.sample * @time_multipliers.sample) * 1000).round
      )
    end
  end

  def create_fake_snapshot(method, path, duration, started_at)
    page = Rack::MiniProfiler::TimerStruct::Page.new({
      'PATH_INFO' => path,
      'REQUEST_METHOD' => method
    })
    page[:root].record_time(duration)
    page[:started_at] = started_at
    page[:sql_count] = (SecureRandom.rand * @multipliers.sample).round
    page[:custom_fields]["Application Version"] = SecureRandom.hex
    page[:custom_fields]["User"] = %w[Anon Logged-in].sample
    page
  end
end

Rack::MiniProfiler.config.enable_advanced_debugging_tools = true
Rack::MiniProfiler.config.storage = SampleStorage
Rack::MiniProfiler.config.snapshot_hidden_custom_fields += ["application Version"]
Rack::MiniProfiler.config.storage_failure = ->(e) do
  puts e
end

class Rack::MiniProfiler
  private

  def cache_control_value
    0
  end
end

class Sample < Sinatra::Base
  use Rack::MiniProfiler
  def fib(n)
    return 1 if n <= 2
    fib(n - 1) + fib(n - 2)
  end

  get '/' do
    help = <<~TEXT
      To the left of this page there should be a speed
      badge with data from a real application (Discourse).
      The data is modified so that it has as many UI elements
      as possible to make easy and fun to do front-end development.
      Refreshing this page should be enough to see any changes
      you make to files in the <code>lib/html</code> directory.
    TEXT
    <<~HTML.dup
      <html>
        <head></head>
        <body>
          <div style="margin: auto; width: 660px; font-family: Arial">
            <h2>Rack Mini Profiler</h2>
            <p>#{help.split("\n").join(' ')}</p>
          </div>
        </body>
      </html>
    HTML
  end

  get '/test_flamegraph' do
    5.times { |n| fib(31 + n); sleep 0.1 }
    +"This page is for testing flamegraphs. Append `?pp=flamegraph` to see a flamegraph for this page."
  end
end
