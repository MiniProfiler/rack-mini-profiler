# frozen_string_literal: true

describe Rack::MiniProfiler::FileStore do

  context 'page struct' do

    before do
      tmp = File.expand_path(__FILE__ + "/../../../tmp")
      Dir::mkdir(tmp) unless File.exist?(tmp)
      @store = Rack::MiniProfiler::FileStore.new(path: tmp)
    end

    describe 'allowed_tokens' do

      it 'should return tokens' do
        @store.flush_tokens

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

    describe 'storage' do

      it 'can store a PageStruct and retrieve it' do
        page_struct = Rack::MiniProfiler::TimerStruct::Page.new({})
        page_struct[:id] = "XYZ"
        page_struct[:random] = "random"
        @store.save(page_struct)
        page_struct = @store.load('XYZ')
        expect(page_struct[:random]).to eq("random")
        expect(page_struct[:id]).to eq("XYZ")
      end

      it 'can list unviewed items for a user' do
        @store.set_unviewed('a', 'XYZ')
        @store.set_unviewed('a', 'ABC')
        expect(@store.get_unviewed_ids('a').sort.to_a).to eq(['XYZ', 'ABC'].sort.to_a)
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

end
