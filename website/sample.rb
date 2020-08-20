# frozen_string_literal: true

require 'rack-mini-profiler'
require 'sinatra'
require 'sinatra/base'

class SampleStorage < Rack::MiniProfiler::AbstractStore
  def initialize(args)
    @multipliers = [10, 100, 1000]
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

  def snapshots_overview
    [
      {
        name: "GET topics#list",
        worst_score: SecureRandom.rand * @multipliers.sample
      },
      {
        name: "GET users#list",
        worst_score: SecureRandom.rand * @multipliers.sample
      },
      {
        name: "GET /a/very/long/path/that/doesnt/exist",
        worst_score: SecureRandom.rand * @multipliers.sample
      }
    ]
  end

  def group_snapshots_list(*args)
    units = [1, 60, 3600, 3600 * 24]
    multipliers = (1..60).to_a
    (3..15).to_a.sample.times.to_a.map do
      {
        id: SecureRandom.hex,
        duration: SecureRandom.rand * @multipliers.sample,
        timestamp: ((Time.new.to_f - units.sample * multipliers.sample) * 1000).round
      }
    end
  end
end

Rack::MiniProfiler.config.storage = SampleStorage
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
end
