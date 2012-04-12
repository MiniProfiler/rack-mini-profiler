require 'spec_helper'
require 'rack-mini-profiler'

describe Rack::MiniProfiler do

  describe 'unique id' do

    before do
      @unique = Rack::MiniProfiler.generate_id
    end

    it 'is not nil' do
      @unique.should_not be_nil
    end

    it 'is not empty' do
      @unique.should_not be_empty
    end

    # TODO: Way more specs
    describe 'step' do

      it 'yields the block given' do
        Rack::MiniProfiler.step('test') { "hello" }.should == "hello"
      end

      describe 'current' do

        before do
          Rack::MiniProfiler.create_current
        end

        it 'yields the block given' do
          Rack::MiniProfiler.step('test') { "mini profiler" }.should == "mini profiler"
        end

      end

    end

  end

end
