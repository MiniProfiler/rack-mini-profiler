require 'spec_helper'

describe Rack::MiniProfiler::GCProfiler do
  before :each do
    @app = lambda do |env|
      env
    end
    @env = {}
    @profiler = Rack::MiniProfiler::GCProfiler.new
  end

  describe '#profile_gc' do
    it 'doesn\'t leave the GC enabled if it was disabled previously' do
      GC.disable

      expect {
        @profiler.profile_gc(@app, @env)
      }.to_not change { GC.disable }

      # Let's re-enable the GC for the rest of the test suite
      GC.enable
    end

    it 'keeps the GC enabled if it was enabled previously' do
      expect {
        @profiler.profile_gc(@app, @env)
      }.to_not change { GC.enable }
    end

  end
end
