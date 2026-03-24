# frozen_string_literal: true

require "spec_helper"

RSpec.describe "rperf flamegraph integration" do
  before do
    skip "rperf not available" unless defined?(Rperf) && Rperf.respond_to?(:start)
  end

  let(:profiler) { Rack::MiniProfiler.new(app) }
  let(:app) { lambda { |_env| [200, {}, ["ok"]] } }

  before do
    Rack::MiniProfiler.reset_config
    Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore
    Rack::MiniProfiler.config.flamegraph_profiler = :rperf
  end

  it "returns error when rperf is not installed" do
    hide_const("Rperf")
    response = profiler.call({ "PATH_INFO" => "/", "QUERY_STRING" => "pp=flamegraph" })
    expect(response[2]).to include("Please install the rperf gem")
  end

  it "generates valid speedscope JSON for flamegraph" do
    require "rperf"
    Rack::MiniProfiler.config.flamegraph_profiler = :rperf
    response = profiler.call({ "PATH_INFO" => "/", "QUERY_STRING" => "pp=flamegraph" })
    expect(response[0]).to eq(200)
    body = response[2].join
    expect(body).to include("speedscope")
  end
end
