require 'spec_helper'

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

      it 'allows us to start the profiler disabled' do
        Rack::MiniProfiler.config.enabled = false
        Rack::MiniProfiler.config.enabled.should == false
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
  end

  describe 'profile method' do
    before do
      Rack::MiniProfiler.create_current
      class TestClass
        def foo(bar,baz)
          return [bar, baz, yield]
        end
      end
    end

    it 'should not destroy a method' do
      Rack::MiniProfiler.profile_method TestClass, :foo
      TestClass.new.foo("a","b"){"c"}.should == ["a","b","c"]
      Rack::MiniProfiler.unprofile_method TestClass, :foo
    end

  end

  describe 'step' do

    describe 'basic usage' do
      it 'yields the block given' do
        Rack::MiniProfiler.create_current
        Rack::MiniProfiler.step('test') { "mini profiler" }.should == "mini profiler"
      end
    end


    describe 'typical usage' do
      before(:all) do
        Rack::MiniProfiler.create_current
        Time.now = Time.new
        Time.now += 1
        Rack::MiniProfiler.step('outer') {
          Time.now +=  2
          Rack::MiniProfiler.step('inner') {
            Time.now += 3
          }
          Time.now += 4
        }
        @page_struct = Rack::MiniProfiler.current.page_struct
        @root = @page_struct.root
        @root.record_time

        @outer = @page_struct.root.children[0]
        @inner = @outer.children[0]
      end

      after(:all) do
        Time.back_to_normal
      end

      it 'measures total duration correctly' do
        @page_struct.duration_ms.to_i.should == 10 * 1000
      end

      it 'measures outer start time correctly' do
        @outer.start_ms.to_i.should == 1 * 1000
      end

      it 'measures outer duration correctly' do
        @outer.duration_ms.to_i.should == 9 * 1000
      end

      it 'measures inner start time correctly' do
        @inner.start_ms.to_i.should == 3 * 1000
      end

      it 'measures inner duration correctly' do
        @inner.duration_ms.to_i.should == 3 * 1000
      end

    end

  end

end
