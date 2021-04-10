# frozen_string_literal: true

module Rack
  describe MiniProfiler::Config do

    describe '.default' do
      it 'has "enabled" set to true' do
        expect(MiniProfiler::Config.default.enabled).to be(true)
      end
    end

    describe 'authorization_mode' do
      before do
        @config = MiniProfiler::Config.default
      end

      it 'is false by default' do
        expect(@config.authorization_mode).to be(:allow_all)
      end

      it 'is set to :allow_authorized when given :whitelist' do
        expect { @config.authorization_mode = :whitelist }.to output(<<~DEP).to_stderr
          [DEPRECATION] `:whitelist` authorization mode is deprecated. Please use `:allow_authorized` instead.
        DEP

        expect(@config.authorization_mode).to eq :allow_authorized
      end

      it 'emits deprecation warning if set to an unrecognized mode' do
        expect { @config.authorization_mode = :unknown_mode }.to output(<<~DEP).to_stderr
          [DEPRECATION] unknown authorization mode unknown_mode. Expected `:allow_all` or `:allow_authorized`.
        DEP
      end
    end
  end
end
