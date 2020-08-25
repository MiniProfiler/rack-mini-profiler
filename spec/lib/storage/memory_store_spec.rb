# frozen_string_literal: true

describe Rack::MiniProfiler::MemoryStore do

  context 'page struct' do

    before do
      @store = Rack::MiniProfiler::MemoryStore.new
    end

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = { id: "XYZ", random: "random" }
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
      old_page_struct = { id: "XYZ", random: "random", started: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - 2) * 1000).to_i }
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

      clock_travel(Process.clock_gettime(Process::CLOCK_MONOTONIC) + 1) do
        new_tokens = @store.allowed_tokens
        expect(new_tokens.length).to eq(1)
        expect(new_tokens).to eq(tokens)
      end

      clock_travel(Process.clock_gettime(Process::CLOCK_MONOTONIC) + Rack::MiniProfiler::AbstractStore::MAX_TOKEN_AGE + 1) do
        new_tokens = @store.allowed_tokens
        expect(new_tokens.length).to eq(2)
        expect((new_tokens - tokens).length).to eq(1)
      end

    end
  end

  include_examples "snapshots storage", Rack::MiniProfiler::MemoryStore.new
end
