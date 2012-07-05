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

    describe 'configuration' do

      it 'allows us to set configuration settings' do
        Rack::MiniProfiler.config.auto_inject = false
        Rack::MiniProfiler.config.auto_inject.should == false
      end

      it 'can reset the settings' do
        Rack::MiniProfiler.config.auto_inject = false
        Rack::MiniProfiler.reset_config
        Rack::MiniProfiler.config.auto_inject.should be_true
      end

      describe 'base_url_path' do
        it 'adds a trailing slash onto the base_url_path' do
          profiler = Rack::MiniProfiler.new(nil, :base_url_path => "/test-resource")
          profiler.config.base_url_path.should == "/test-resource/"
        end

        it "doesn't add the trailing slash when it's already there" do
          profiler = Rack::MiniProfiler.new(nil, :base_url_path => "/test-resource/")
          profiler.config.base_url_path.should == "/test-resource/"
        end

      end      

    end

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
