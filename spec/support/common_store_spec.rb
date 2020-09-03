# frozen_string_literal: true

RSpec.shared_examples "snapshots storage" do |store|
  describe '#should_take_snapshot?' do
    it 'returns true every N calls' do
      store.send(:wipe_snapshots_data)

      expect(store.should_take_snapshot?(3)).to eq(false)
      expect(store.should_take_snapshot?(3)).to eq(false)
      expect(store.should_take_snapshot?(3)).to eq(true)

      expect(store.should_take_snapshot?(3)).to eq(false)
      expect(store.should_take_snapshot?(3)).to eq(false)
      expect(store.should_take_snapshot?(3)).to eq(true)

      expect(store.should_take_snapshot?(3)).to eq(false)

      store.send(:wipe_snapshots_data)

      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(true)

      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(false)
      expect(store.should_take_snapshot?(5)).to eq(true)

      expect(store.should_take_snapshot?(5)).to eq(false)
    end
  end

  describe "#push_snapshot" do
    it 'keeps the worst snapshots and respects the config limit' do
      store.send(:wipe_snapshots_data)

      config = Rack::MiniProfiler::Config.default
      config.snapshots_limit = 3

      pstruct_class = Rack::MiniProfiler::TimerStruct::Page
      pstruct1 = pstruct_class.new({}).tap { |s| s[:root].record_time(30) }
      pstruct2 = pstruct_class.new({}).tap { |s| s[:root].record_time(20) }
      pstruct3 = pstruct_class.new({}).tap { |s| s[:root].record_time(40) }

      store.push_snapshot(pstruct1, config)
      store.push_snapshot(pstruct2, config)
      store.push_snapshot(pstruct3, config)

      store.fetch_snapshots do |snapshots|
        expect(snapshots.map { |s| s[:id] }).to contain_exactly(
          pstruct1[:id],
          pstruct2[:id],
          pstruct3[:id]
        )
      end

      pstruct4 = pstruct_class.new({}).tap { |s| s[:root].record_time(10) }
      pstruct5 = pstruct_class.new({}).tap { |s| s[:root].record_time(50) }

      store.push_snapshot(pstruct4, config)
      store.push_snapshot(pstruct5, config)

      store.fetch_snapshots do |snapshots|
        expect(snapshots.map { |s| s[:id] }).to contain_exactly(
          pstruct1[:id],
          pstruct3[:id],
          pstruct5[:id]
        )
      end
    end
  end

  describe '#fetch_snapshots' do
    it 'respects the batch_size argument' do
      store.send(:wipe_snapshots_data)

      snapshot_ids = 10.times.map do |n|
        page = Rack::MiniProfiler::TimerStruct::Page.new({}).tap do |s|
          s[:root].record_time(n)
          store.push_snapshot(s, Rack::MiniProfiler::Config.default)
        end
        page[:id]
      end

      calls = 0
      store.fetch_snapshots(batch_size: 10) do |snapshots|
        calls += 1
        expect(snapshots.map { |s| s[:id] }).to contain_exactly(*snapshot_ids)
      end
      expect(calls).to eq(1)

      calls = 0
      fetched_snapshots = []
      store.fetch_snapshots(batch_size: 5) do |snapshots|
        calls += 1
        fetched_snapshots.concat(snapshots)
      end
      expect(fetched_snapshots.map { |s| s[:id] }).to contain_exactly(*snapshot_ids)
      expect(calls).to eq(2)

      calls = 0
      fetched_snapshots = []
      store.fetch_snapshots(batch_size: 3) do |snapshots|
        calls += 1
        fetched_snapshots.concat(snapshots)
      end
      expect(fetched_snapshots.map { |s| s[:id] }).to contain_exactly(*snapshot_ids)
      expect(calls).to eq(4)
    end
  end

  describe '#load_snapshot' do
    it 'finds snapshot by id' do
      store.send(:wipe_snapshots_data)

      page = Rack::MiniProfiler::TimerStruct::Page.new({})
      page[:root].record_time(400)
      store.push_snapshot(page, Rack::MiniProfiler::Config.default)

      loaded = store.load_snapshot(page[:id])
      expect(loaded).to be_instance_of(Rack::MiniProfiler::TimerStruct::Page)
      expect(loaded[:id]).to eq(page[:id])
    end

    it 'returns nil for non-existent snapshots' do
      loaded = store.load_snapshot('zcarfasegsadfagdsafsdfsdaf')
      expect(loaded).to eq(nil)
    end
  end
end
