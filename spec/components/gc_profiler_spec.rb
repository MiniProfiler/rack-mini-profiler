require 'spec_helper'

describe Rack::MiniProfiler::GCProfiler do
  before :each do
    @app = lambda do |env|
      env
    end
    @env = {}
    @profiler = Rack::MiniProfiler::GCProfiler.new
  end

  describe '#profile_gc_time' do
    it 'doesn\'t enable the gc if it was disabled previously' do
      GC.disable

      expect {
        @profiler.profile_gc_time(@app, @env)
      }.to_not change { GC.disable }

      # Let's re-enable the GC for the rest of the test suite
      GC.enable
    end

    it 'keeps the GC enable if it was enabled previously' do
      expect {
        @profiler.profile_gc_time(@app, @env)
      }.to_not change { GC.enable }
    end

    it 'doesn\'t leave the GC Profiler enabled if it was disabled previously' do
      GC::Profiler.enable

      expect {
        @profiler.profile_gc_time(@app, @env)
      }.to_not change { GC::Profiler.enabled? }

      GC::Profiler.disable
    end


    it 'keeps the GC Profiler disabled if it was disabled previously' do
      expect {
        @profiler.profile_gc_time(@app, @env)
      }.to_not change { GC::Profiler.enabled? }
    end
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
