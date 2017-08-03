require 'spec_helper'

describe Rack::MiniProfiler::MemoryStore do

  context 'page struct' do

    before do
      @store = Rack::MiniProfiler::MemoryStore.new
    end

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = {:id => "XYZ", :random => "random"}
        @store.save(page_struct)
        page_struct = @store.load("XYZ")
        expect(page_struct[:id]).to eq("XYZ")
        expect(page_struct[:random]).to eq("random")
      end

      it 'can list unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        expect(@store.get_unviewed_ids('a')).to eq(['XYZ', 'ABC'])
      end

      it 'can set all unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_all_unviewed('a', %w(111 222))
        expect(@store.get_unviewed_ids('a')).to eq(['111', '222'])
        @store.set_all_unviewed('a', [])
      end

      it 'can set an item to viewed once it is unviewed' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        @store.set_viewed('a', 'XYZ')
        expect(@store.get_unviewed_ids('a')).to eq(['ABC'])
      end

    end

  end


  describe 'cleanup_cache' do
    before do
      @fast_expiring_store = Rack::MiniProfiler::MemoryStore.new(expires_in: 1)
    end

    it "cleans up expired values" do
      old_page_struct = {:id => "XYZ", :random => "random", :started => ((Time.now.to_f - 2) * 1000).to_i }
      @fast_expiring_store.save(old_page_struct)
      old_page_struct = @fast_expiring_store.load("XYZ")
      expect(old_page_struct[:id]).to eq("XYZ")
      @fast_expiring_store.cleanup_cache
      page_struct = @fast_expiring_store.load("XYZ")
      expect(page_struct).to eq(nil)
    end
  end

  describe 'allowed_tokens' do
    before do
      @store = Rack::MiniProfiler::MemoryStore.new
    end

    it 'should return tokens' do

      tokens = @store.allowed_tokens
      expect(tokens.length).to eq(1)
      expect(tokens).to eq(@store.allowed_tokens)

      Time.travel(Time.now + 1) do
        new_tokens = @store.allowed_tokens
        expect(new_tokens.length).to eq(1)
        expect(new_tokens).to eq(tokens)
      end

      Time.travel(Time.now + Rack::MiniProfiler::AbstractStore::MAX_TOKEN_AGE + 1) do
        new_tokens = @store.allowed_tokens
        expect(new_tokens.length).to eq(2)
        expect((new_tokens - tokens).length).to eq(1)
      end

    end
  end

  describe 'cache cleanup thread' do
    let(:described){Rack::MiniProfiler::MemoryStore::CacheCleanupThread}
    before do
      store = double()
      allow(store).to receive(:cleanup_cache)
      @cleaner = described.new(1, 2, store) do
        self.sleepy_run
      end
    end

    it "just run on start" do
      expect(@cleaner.should_cleanup?).to eq(false)
    end

    it "when number of runs * interval gets bigger than cycle, it should cleanup" do
      @cleaner.increment_cycle
      expect(@cleaner.should_cleanup?).to eq(true)
    end

    describe 'cleanup' do
      before do
        store = double()
        expect(store).to receive(:cleanup_cache) { true }
        @cleaner = described.new(1, 2, store) do
          self.sleepy_run
        end
      end
      it "calls store" do
        @cleaner.cleanup
      end

      it "resets counter" do
        @cleaner.increment_cycle
        expect(@cleaner.cycle_count).to eq(2)
        @cleaner.cleanup
        expect(@cleaner.cycle_count).to eq(1)
      end
    end

    describe 'sleepy_run' do
      before do
        store = double()
        allow(store).to receive(:cleanup_cache)
        @cleaner = described.new(0, 0, store) do
          self.sleepy_run
        end
      end
      it "works" do
        @cleaner.sleepy_run
      end
    end
  end
end
