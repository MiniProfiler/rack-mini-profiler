# frozen_string_literal: true

describe Rack::MiniProfiler do
  describe 'unique id' do

    before do
      @unique = Rack::MiniProfiler.generate_id
    end

    it 'is not nil' do
      expect(@unique).not_to be_nil
    end

    it 'is not empty' do
      expect(@unique).not_to be_empty
    end

    describe 'configuration' do

      it 'allows us to set configuration settings' do
        Rack::MiniProfiler.config.auto_inject = false
        expect(Rack::MiniProfiler.config.auto_inject).to eq(false)
      end

      it 'allows us to start the profiler disabled' do
        Rack::MiniProfiler.config.enabled = false
        expect(Rack::MiniProfiler.config.enabled).to eq(false)
      end

      it 'can reset the settings' do
        Rack::MiniProfiler.config.auto_inject = false
        Rack::MiniProfiler.reset_config
        expect(Rack::MiniProfiler.config.auto_inject).to be(true)
      end

      describe 'base_url_path' do
        it 'adds a trailing slash onto the base_url_path' do
          profiler = Rack::MiniProfiler.new(nil, base_url_path: "/test-resource")
          expect(profiler.config.base_url_path).to eq("/test-resource/")
        end

        it "doesn't add the trailing slash when it's already there" do
          profiler = Rack::MiniProfiler.new(nil, base_url_path: "/test-resource/")
          expect(profiler.config.base_url_path).to eq("/test-resource/")
        end

      end

    end
  end

  describe 'profile method' do
    class TestClass
      def foo(bar, baz)
        [bar, baz, yield]
      end

      def kwargs_test(a, b, c = 1, d: 4)
        { a: a, b: b, c: c, d: d }
      end

      def self.bar(baz, boo)
        [baz, boo, yield]
      end
    end

    before do
      Rack::MiniProfiler.create_current
    end

    it 'should not destroy a method' do
      Rack::MiniProfiler.profile_method TestClass, :foo
      expect(TestClass.new.foo("a", "b") { "c" }).to eq(["a", "b", "c"])
      Rack::MiniProfiler.unprofile_method TestClass, :foo
    end

    it 'should not destroy a singleton method' do
      Rack::MiniProfiler.profile_singleton_method TestClass, :bar
      expect(TestClass.bar("a", "b") { "c" }).to eq(["a", "b", "c"])
      Rack::MiniProfiler.unprofile_singleton_method TestClass, :bar
    end

    it 'optional positional args and keyword args should not conflict' do
      block_args = nil
      Rack::MiniProfiler.profile_method(TestClass, :kwargs_test) do |a, b, c = 1, d: 4|
        block_args = { a: a, b: b, c: c, d: d }
      end
      expect(TestClass.new.kwargs_test(10, 20, d: 90)).to eq({ a: 10, b: 20, c: 1, d: 90 })
      expect(block_args).to eq({ a: 10, b: 20, c: 1, d: 90 })
    end
  end

  describe 'step' do

    describe 'basic usage' do
      it 'yields the block given' do
        Rack::MiniProfiler.create_current
        expect(Rack::MiniProfiler.step('test') { "mini profiler" }).to eq("mini profiler")
      end
    end

    describe 'typical usage' do
      before do
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        clock_set(start)
        Rack::MiniProfiler.create_current
        clock_set(start + 1)

        Rack::MiniProfiler.step('outer') {
          clock_set(start + 1 + 2)
          Rack::MiniProfiler.step('inner') {
            clock_set(start + 1 + 2 + 3)
          }
          clock_set(start + 1 + 2 + 3 + 4)
        }

        @page_struct = Rack::MiniProfiler.current.page_struct
        @root = @page_struct.root
        @root.record_time

        @outer = @page_struct.root.children[0]
        @inner = @outer.children[0]
      end

      after do
        clock_back_to_normal
      end

      it 'measures total duration correctly' do
        expect(@page_struct.duration_ms).to be_within(0.1).of(10 * 1000)
      end

      it 'measures outer start time correctly' do
        expect(@outer.start_ms).to be_within(0.1).of(1 * 1000)
      end

      it 'measures outer duration correctly' do
        expect(@outer.duration_ms).to be_within(0.1).of(9 * 1000)
      end

      it 'measures inner start time correctly' do
        expect(@inner.start_ms).to be_within(0.1).of(3 * 1000)
      end

      it 'measures inner duration correctly' do
        expect(@inner.duration_ms).to be_within(0.1).of(3 * 1000)
      end
    end
  end

  describe '#ids' do
    let(:profiler) do
      Rack::MiniProfiler.new(nil, base_url_path: "/test-resource",
                                  storage: Rack::MiniProfiler::MemoryStore,
                                  user_provider: Proc.new { |env| user_id },
                            )
    end

    let(:current) { Rack::MiniProfiler.create_current }
    let(:current_id) { current.page_struct[:id] }
    let(:user_id) { "user1" }
    let(:storage) { profiler.instance_variable_get(:@storage) } # not perfect but ...
    before do
      current
    end

    it "returns current id" do
      expect(profiler.ids(user_id)).to eq([current_id])
    end

    it "uses existing ids" do
      storage.set_unviewed(user_id, 1)
      storage.set_unviewed(user_id, 2)

      expect(profiler.ids(user_id)).to eq([current_id, 1, 2])
    end

    it "caps at config.max_traces_to_show ids" do
      25.times { |i| storage.set_unviewed(user_id, i + 1) }

      expect(profiler.ids(user_id)).to eq([current_id, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                                           11, 12, 13, 14, 15, 16, 17, 18, 19])
    end
  end

  describe '.snapshots_transporter?' do
    it 'returns true only if both destination URL and auth key are set' do
      expect(Rack::MiniProfiler.snapshots_transporter?).to eq(false)

      Rack::MiniProfiler.config.snapshots_transport_destination_url = 'http://example.com'
      expect(Rack::MiniProfiler.snapshots_transporter?).to eq(false)

      Rack::MiniProfiler.config.snapshots_transport_auth_key = 'somekeyhere'
      Rack::MiniProfiler.config.snapshots_transport_destination_url = nil
      expect(Rack::MiniProfiler.snapshots_transporter?).to eq(false)

      Rack::MiniProfiler.config.snapshots_transport_destination_url = 'http://example.com'
      expect(Rack::MiniProfiler.snapshots_transporter?).to eq(true)
    end
  end

  describe '#call' do
    let(:app) { lambda { |env| [200, {}, ["OK"]] } }
    let(:profiler) { Rack::MiniProfiler.new(app) }

    it "returns error response when stackprof isn't installed" do
      response = profiler.call({ "PATH_INFO" => "/", "QUERY_STRING" => "pp=flamegraph" })

      expect(response).to eq([
        200,
        { "Content-Type" => "text/plain; charset=utf-8", "Set-Cookie" => "__profilin=p%3Dt; path=/; HttpOnly; SameSite=Lax" },
        ["Please install the stackprof gem and require it: add gem 'stackprof' to your Gemfile"],
      ])
    end

    it "returns error response when memory_profiler isn't installed" do
      original_enable_advanced_debugging_tools = Rack::MiniProfiler.config.enable_advanced_debugging_tools
      Rack::MiniProfiler.config.enable_advanced_debugging_tools = true

      response = profiler.call({ "PATH_INFO" => "/", "QUERY_STRING" => "pp=profile-memory" })

      expect(response).to eq([
        500,
        { "Content-Type" => "text/plain; charset=utf-8", "Set-Cookie" => "__profilin=p%3Dt; path=/; HttpOnly; SameSite=Lax" },
        ["Please install the memory_profiler gem and require it: add gem 'memory_profiler' to your Gemfile"],
      ])

    ensure
      Rack::MiniProfiler.config.enable_advanced_debugging_tools = original_enable_advanced_debugging_tools
    end
  end
end
