# frozen_string_literal: true

require 'securerandom'
require 'rack/test'
require File.expand_path('../../../lib/mini_profiler_rails/railtie_methods', __FILE__)

def to_seconds(array)
  array.map! { |n, s, f| [n, s / 1000.0, f / 1000.0] }
  array
end

describe Rack::MiniProfilerRailsMethods do
  describe '#render_notification_handler' do
    before do
      allow(Process).to receive(:clock_gettime).and_return(0)
      Rack::MiniProfiler.create_current
      @current_timer = Rack::MiniProfiler.current.current_timer

      # SQL timings
      to_seconds([
        ['SELECT A', 2,   04], # in node A
        ['SELECT B', 6,   15], # in node B
        ['SELECT E', 73,  77], # in node E
        ['SELECT F', 93,  96]  # in node F
      ]).each do |query, start, finish|
        allow(Process).to receive(:clock_gettime).and_return(finish)
        @current_timer.add_sql(
          query,
          finish - start,
          Rack::MiniProfiler.current.page_struct
        )
      end

      # Custom timings
      to_seconds([
        ['custom1 D', 53, 55],
        ['custom1 D', 57, 60],
        ['custom2 D', 55, 57],
        ['custom1 F', 90, 99],
        ['custom1 B', 11, 16],
        ['custom1 B', 17, 19]
      ]).each do |type, start, finish|
        allow(Process).to receive(:clock_gettime).and_return(finish)
        timing = @current_timer.add_custom(
          type,
          finish - start,
          Rack::MiniProfiler.current.page_struct
        )
        @custom_timings ||= {}
        @custom_timings[type] ||= []
        @custom_timings[type] << timing
      end

      # Request nodes that are created when rails fires an ActiveSupport
      # notification when a template is done rendering.
      # Templates are usually nested, so we attempt to rearrange the nodes
      # so that they're nested in the same way as the templates they represent.

      # The order of the nodes here is the same order of the AS notifications
      # we get for them when they're done rendering.
      # B finishes first, F finishes last

      # [name, start, finish] units are ms which are converted by `to_seconds` to seconds
      to_seconds([
        ['B',  5,     20],
        ['D',  50,    60],
        ['C',  40,    70],
        ['E',  70,    80],
        ['A',  0,     80],
        ['F',  90,    100]
      ]).each do |name, start, finish|
        allow(Process).to receive(:clock_gettime).and_return(finish)
        described_class.render_notification_handler(name, finish, start, name_as_description: true)
      end
      @nodes = {
        A: @current_timer.children[0],
        F: @current_timer.children[1]
      }
      @nodes.merge!(
        B: @nodes[:A].children[0],
        C: @nodes[:A].children[1],
        E: @nodes[:A].children[2]
      )
      @nodes.merge!(
        D: @nodes[:C].children[0]
      )

      # This is how the nodes should be nested after they do through
      # render_notification_handler:
      #  ['A', 0, 80],
      #      ['B', 5, 20],
      #      ['C', 40, 70],
      #          ['D', 50, 60],
      #      ['E', 70, 80],
      #  ['F', 90, 100]
      # A is parent for B, C and E
      # C is parent for D
      # A and F are siblings
    end

    it 'should be able to nest the nodes correctly' do
      @nodes.each do |key, node|
        expect(key.to_s).to eq(node.name)
      end
      top_nodes = @current_timer.children
      expect(top_nodes.map(&:name)).to eq(%w{A F})
      expect(@nodes[:A].children.map(&:name)).to eq(%w{B C E})
      expect(@nodes[:C].children.map(&:name)).to eq(%w{D})

      without_children = %i{B D E F}
      without_children.each do |name|
        expect(@nodes[name].children).to eq([])
      end
    end

    it 'should correct the duration_milliseconds and duration_without_children_milliseconds attributes for the nodes' do
      dm = :duration_milliseconds
      dwcm = :duration_without_children_milliseconds

      expect(@nodes[:A][dm].round).to eq(80)
      expect(@nodes[:A][dwcm].round).to eq(80 - (15 + 30 + 10))

      expect(@nodes[:B][dm].round).to eq(15)
      expect(@nodes[:B][dwcm].round).to eq(15)

      expect(@nodes[:C][dm].round).to eq(30)
      expect(@nodes[:C][dwcm].round).to eq(30 - 10)

      expect(@nodes[:D][dm].round).to eq(10)
      expect(@nodes[:D][dwcm].round).to eq(10)

      expect(@nodes[:E][dm].round).to eq(10)
      expect(@nodes[:E][dwcm].round).to eq(10)

      expect(@nodes[:F][dm].round).to eq(10)
      expect(@nodes[:F][dwcm].round).to eq(10)
    end

    it 'should move sql timings to the correct nodes' do
      %i{A B E F}.each do |name|
        sql_timings = @nodes[name].sql_timings
        expect(sql_timings.size).to eq(1)
        expect(sql_timings[0][:formatted_command_string]).to eq("SELECT #{name}")
      end
      expect(@current_timer.sql_timings).to eq([])
    end

    it 'should move custom timings to the correct nodes' do
      ct = :custom_timings
      cts = :custom_timing_stats

      expect(@nodes[:D][ct].size).to eq(2)
      expect(@nodes[:D][cts].size).to eq(2)
      expect(@nodes[:D][ct]['custom1 D'].size).to eq(2)
      expect(@nodes[:D][ct]['custom1 D']).to eq(@custom_timings['custom1 D'])
      expect(@nodes[:D][cts]['custom1 D'][:count]).to eq(2)
      expect((@nodes[:D][cts]['custom1 D'][:duration] * 1000).round).to eq(2 + 3)

      expect(@nodes[:D][ct]['custom2 D'].size).to eq(1)
      expect(@nodes[:D][ct]['custom2 D']).to eq(@custom_timings['custom2 D'])
      expect(@nodes[:D][cts]['custom2 D'][:count]).to eq(1)
      expect((@nodes[:D][cts]['custom2 D'][:duration] * 1000).round).to eq(2)

      expect(@nodes[:F][ct].size).to eq(1)
      expect(@nodes[:F][cts].size).to eq(1)
      expect(@nodes[:F][ct]['custom1 F'].size).to eq(1)
      expect(@nodes[:F][ct]['custom1 F']).to eq(@custom_timings['custom1 F'])
      expect(@nodes[:F][cts]['custom1 F'][:count]).to eq(1)
      expect((@nodes[:F][cts]['custom1 F'][:duration] * 1000).round).to eq(9)

      expect(@nodes[:B][ct].size).to eq(1)
      expect(@nodes[:B][cts].size).to eq(1)
      expect(@nodes[:B][ct]['custom1 B'].size).to eq(2)
      expect(@nodes[:B][ct]['custom1 B']).to eq(@custom_timings['custom1 B'])
      expect(@nodes[:B][cts]['custom1 B'][:count]).to eq(2)
      expect((@nodes[:B][cts]['custom1 B'][:duration] * 1000).round).to eq(5 + 2)

      expect(@current_timer[ct]).to eq({})
      expect(@current_timer[cts]).to eq({})
    end
  end

  it '#get_webpacker_assets_path returns webpacker public_output_path if webpacker exists' do
    expect(described_class.get_webpacker_assets_path()).to eq(nil)
    ENV['RAILS_ENV'] = 'test'
    require 'rails'
    require 'webpacker'
    tmp_path = Pathname.new("/tmp/rails_root_#{SecureRandom.hex}")
    FileUtils.mkdir(tmp_path)
    Webpacker.instance = Webpacker::Instance.new(
      root_path: tmp_path,
      config_path: Pathname.new(File.expand_path("../fixtures/webpacker.yml", __dir__))
    )
    expect(described_class.get_webpacker_assets_path()).to eq("/some/assets/path")
  ensure
    FileUtils.rm_rf(tmp_path)
  end
end
