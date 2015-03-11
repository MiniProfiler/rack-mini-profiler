require 'spec_helper'

module Rack
  describe MiniProfiler::Config do

    describe '.default' do
      it 'has "enabled" set to true' do
        MiniProfiler::Config.default.enabled.should be_true
      end
    end

  end
end