# frozen_string_literal: true

RSpec.shared_examples "snapshots storage" do |store|
  before do
    store.send(:wipe_snapshots_data)
  end

  describe '#should_take_snapshot?' do
    it 'returns true once every N calls' do
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

  describe '#push_snapshot' do
    it 'updates the score of the group in the overview set' do
      pstruct1 = page_class.new({}).tap { |s| s[:root].record_time(10.0) }
      store.push_snapshot(pstruct1, 'group1', config)
      overview = store.snapshots_overview
      expect(overview.size).to eq(1)
      expect(overview.first[:worst_score]).to eq(10.0)

      pstruct2 = page_class.new({}).tap { |s| s[:root].record_time(20.0) }
      store.push_snapshot(pstruct2, 'group1', config)
      overview = store.snapshots_overview
      expect(overview.size).to eq(1)
      expect(overview.first[:worst_score]).to eq(20.0)

      pstruct3 = page_class.new({}).tap { |s| s[:root].record_time(5.0) }
      store.push_snapshot(pstruct3, 'group1', config)
      overview = store.snapshots_overview
      expect(overview.size).to eq(1)
      expect(overview.first[:worst_score]).to eq(20.0)
    end

    it 'deletes the group of the best perf when the groups limit is exceeded' do
      config.max_snapshot_groups = 2
      pstruct1 = page_class.new({}).tap { |s| s[:root].record_time(10.0) }
      store.push_snapshot(pstruct1, 'group1', config)

      pstruct2 = page_class.new({}).tap { |s| s[:root].record_time(20.0) }
      store.push_snapshot(pstruct2, 'group2', config)

      worst_scores = store.snapshots_overview.map { |group| group[:worst_score] }
      expect(worst_scores.size).to eq(2)
      expect(worst_scores).to contain_exactly(20.0, 10.0)
      expect(store.snapshots_group('group1').size).to be > 0
      expect(store.snapshots_group('group2').size).to be > 0

      pstruct3 = page_class.new({}).tap { |s| s[:root].record_time(30.0) }
      store.push_snapshot(pstruct3, 'group3', config)

      worst_scores = store.snapshots_overview.map { |group| group[:worst_score] }
      expect(worst_scores.size).to eq(2)
      expect(worst_scores).to contain_exactly(30.0, 20.0)
      expect(store.snapshots_group('group1').size).to be == 0
      expect(store.snapshots_group('group2').size).to be > 0
      expect(store.snapshots_group('group3').size).to be > 0

      pstruct4 = page_class.new({}).tap { |s| s[:root].record_time(5.0) }
      store.push_snapshot(pstruct4, 'group4', config)

      worst_scores = store.snapshots_overview.map { |group| group[:worst_score] }
      expect(worst_scores.size).to eq(2)
      expect(worst_scores).to contain_exactly(30.0, 20.0)
      expect(store.snapshots_group('group1').size).to be == 0
      expect(store.snapshots_group('group2').size).to be > 0
      expect(store.snapshots_group('group3').size).to be > 0
      expect(store.snapshots_group('group4').size).to be == 0
    end

    it 'deletes the snapshot of the best perf in the group when the per-group limit is exceeded' do
      config.max_snapshots_per_group = 2
      pstruct1 = page_class.new({}).tap { |s| s[:root].record_time(10.0) }
      store.push_snapshot(pstruct1, 'group1', config)

      pstruct2 = page_class.new({}).tap { |s| s[:root].record_time(20.0) }
      store.push_snapshot(pstruct2, 'group1', config)

      durations = store.snapshots_group('group1').map { |s| s[:duration] }
      expect(durations).to contain_exactly(20.0, 10.0)

      pstruct3 = page_class.new({}).tap { |s| s[:root].record_time(30.0) }
      store.push_snapshot(pstruct3, 'group1', config)

      durations = store.snapshots_group('group1').map { |s| s[:duration] }
      expect(durations).to contain_exactly(30.0, 20.0)

      pstruct4 = page_class.new({}).tap { |s| s[:root].record_time(5.0) }
      store.push_snapshot(pstruct4, 'group1', config)

      durations = store.snapshots_group('group1').map { |s| s[:duration] }
      expect(durations).to contain_exactly(30.0, 20.0)
    end
  end

  describe '#fetch_snapshots_group' do
    it 'returns all snapshots of the requested group' do
      page1 = page_class.new({}).tap { |s| s[:root].record_time(1.0) }
      store.push_snapshot(page1, 'group1', config)

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(page1[:id])

      page2 = page_class.new({}).tap { |s| s[:root].record_time(2.0) }
      store.push_snapshot(page2, 'group1', config)

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(page1[:id], page2[:id])

      page3 = page_class.new({}).tap { |s| s[:root].record_time(2.0) }
      store.push_snapshot(page3, 'group2', config)

      snapshots = store.fetch_snapshots_group('group1')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(page1[:id], page2[:id])
      snapshots = store.fetch_snapshots_group('group2')
      expect(snapshots.map { |s| s[:id] }).to contain_exactly(page3[:id])
    end
  end

  describe '#load_snapshot' do
    it 'finds snapshot by id' do
      store.send(:wipe_snapshots_data)

      page = Rack::MiniProfiler::TimerStruct::Page.new({})
      page[:root].record_time(400)
      store.push_snapshot(page, 'group1', Rack::MiniProfiler::Config.default)

      loaded = store.load_snapshot(page[:id], 'group1')
      expect(loaded).to be_instance_of(Rack::MiniProfiler::TimerStruct::Page)
      expect(loaded[:id]).to eq(page[:id])
    end

    it 'returns nil for non-existent snapshots' do
      store.send(:wipe_snapshots_data)

      page = Rack::MiniProfiler::TimerStruct::Page.new({})
      page[:root].record_time(400)
      store.push_snapshot(page, 'group1', Rack::MiniProfiler::Config.default)

      loaded = store.load_snapshot('idontexist', 'group1')
      expect(loaded).to eq(nil)
    end

    it 'returns nil for non-existent snapshot group' do
      store.send(:wipe_snapshots_data)

      page = Rack::MiniProfiler::TimerStruct::Page.new({})
      page[:root].record_time(400)
      store.push_snapshot(page, 'group1', Rack::MiniProfiler::Config.default)

      loaded = store.load_snapshot(page[:id], 'groupdoesnotexist')
      expect(loaded).to eq(nil)
    end
  end
end
