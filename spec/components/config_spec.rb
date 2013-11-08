require 'spec_helper'
require 'rack-mini-profiler'

module Rack
  describe MiniProfiler::Config do

    describe '.default' do
      it 'has "disabled" set to false' do
        MiniProfiler::Config.default.start_disabled.should be_false
      end
    end

  end
end