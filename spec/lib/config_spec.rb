# frozen_string_literal: true

module Rack
  describe MiniProfiler::Config do

    describe '.default' do
      it 'has "enabled" set to true' do
        expect(MiniProfiler::Config.default.enabled).to be(true)
      end
    end

  end
end
