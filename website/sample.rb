# frozen_string_literal: true

require 'rack-mini-profiler'
require 'sinatra'
require 'sinatra/base'

class Sample < Sinatra::Base
  use Rack::MiniProfiler

  @@data = JSON.parse(File.read(File.expand_path("data.json", __dir__)), symbolize_names: true)
  @@page_struct = Rack::MiniProfiler::TimerStruct::Page.allocate
  @@page_struct.instance_variable_set(:@attributes, @@data)
  @@patched = false

  get '/' do
    storage_instance = Rack::MiniProfiler.config.storage_instance
    storage_instance.instance_variable_set(:@timer_struct_cache, {})
    storage_instance.instance_variable_set(:@user_view_cache, {})
    storage_instance.save(@@page_struct)
    patch_mini_profiler(@@page_struct) unless @@patched
    help = <<~TEXT
      To the left of this page there should be 2 speed badges.
      The first one (with small load time) represents metrics for this particular page.
      The other one (with ~2.5 seconds load time) is taken from a real application (Discourse),
      modified so that it has as many UI elements as possible and always included with this page
      to make easier for you to test your JavaScript and CSS changes. Refreshing this page should
      be enough to see any changes you make to files in the <code>lib/html</code> directory.
    TEXT
    body = <<~HTML
      <html>
        <head>
        </head>
        <body>
          <div style="margin: auto; width: 660px; font-family: Arial">
            <h2>Rack Mini Profiler</h2>
            <p>#{help.split("\n").join(' ')}</p>
          </div>
        </body>
      </html>
    HTML
    body.dup
  end

  def patch_mini_profiler(page)
    Rack::MiniProfiler.send(:define_method, :cache_control_value) do |*args|
      0
    end

    Rack::MiniProfiler.send(:alias_method, :ids_original, :ids)
    Rack::MiniProfiler.send(:define_method, :ids) do |*args, &blk|
      s = self.send(:ids_original, *args, &blk)
      s << page[:id]
      s
    end
    @@patched = true
  end
end
