# frozen_string_literal: true

describe 'common store functionalities' do
  def get_page_struct
    Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  def get_config
    Rack::MiniProfiler::Config.default
  end

  redis_store = Rack::MiniProfiler::RedisStore.new(db: 2)

  memory_store = Rack::MiniProfiler::MemoryStore.new

  describe 'snapshots' do
    before(:each) do
      redis_store.send(:wipe_snapshots_data)
      memory_store.send(:wipe_snapshots_data)
    end

    [redis_store, memory_store].each do |store|
      class_name = store.class
      describe "#{class_name}#should_take_snapshot?" do
        it "returns true once every n times it's called" do
          expect(store.should_take_snapshot?(5)).to eq(false)
          expect(store.should_take_snapshot?(5)).to eq(false)
          expect(store.should_take_snapshot?(5)).to eq(false)
          expect(store.should_take_snapshot?(5)).to eq(false)
          expect(store.should_take_snapshot?(5)).to eq(true)

          store.send(:wipe_snapshots_data)
          expect(store.should_take_snapshot?(3)).to eq(false)
          expect(store.should_take_snapshot?(3)).to eq(false)
          expect(store.should_take_snapshot?(3)).to eq(true)
          expect(store.should_take_snapshot?(3)).to eq(false)
          expect(store.should_take_snapshot?(3)).to eq(false)
          expect(store.should_take_snapshot?(3)).to eq(true)
          expect(store.should_take_snapshot?(3)).to eq(false)
        end
      end

      describe "#{class_name}#push_snapshot" do
        it 'saves and groups snapshots' do
          config = get_config
          pstruct1 = get_page_struct.tap { |s| s[:root].record_time(10) }
          pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
          pstruct3 = get_page_struct.tap { |s| s[:root].record_time(30) }
          store.push_snapshot(pstruct1, "g1", config)
          store.push_snapshot(pstruct2, "g1", config)
          store.push_snapshot(pstruct3, "g2", config)

          group1 = store.group_snapshots_list("g1")
          group2 = store.group_snapshots_list("g2")
          expect(group1.map { |s| s[:id] }).to contain_exactly(pstruct1[:id], pstruct2[:id])
          expect(group2.map { |s| s[:id] }).to contain_exactly(pstruct3[:id])
        end

        context 'when there are max_snapshot_groups groups' do
          it 'discards the new group if its score is lower than all of the existing groups' do
            config = get_config
            config.max_snapshot_groups = 2
            pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
            pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
            pstruct3 = get_page_struct.tap { |s| s[:root].record_time(10) }
            store.push_snapshot(pstruct1, "g1", config)
            store.push_snapshot(pstruct2, "g2", config)
            store.push_snapshot(pstruct3, "g3", config)

            groups = store.snapshots_overview
            expect(groups.size).to eq(2)
            expect(groups.map { |g| g[:name] }).to contain_exactly("g1", "g2")
            expect(groups.map { |g| g[:worst_score] }).to contain_exactly(30, 20)
          end

          it 'deletes the group with the lowest score and adds the new group if it has a higher score than any of the existing groups' do
            config = get_config
            config.max_snapshot_groups = 2
            pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
            pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
            pstruct3 = get_page_struct.tap { |s| s[:root].record_time(40) }
            store.push_snapshot(pstruct1, "g1", config)
            store.push_snapshot(pstruct2, "g2", config)
            store.push_snapshot(pstruct3, "g3", config)

            groups = store.snapshots_overview
            expect(groups.size).to eq(2)
            expect(groups.map { |g| g[:name] }).to contain_exactly("g1", "g3")
            expect(groups.map { |g| g[:worst_score] }).to contain_exactly(30, 40)
          end
        end

        context 'when adding a new snapshot to a full group' do
          it 'discards the new snapshot if its score is lower than all of the existing snapshots in the group' do
            config = get_config
            config.max_snapshots_per_group = 2
            pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
            pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
            pstruct3 = get_page_struct.tap { |s| s[:root].record_time(10) }

            store.push_snapshot(pstruct1, "g1", config)
            store.push_snapshot(pstruct2, "g1", config)
            store.push_snapshot(pstruct3, "g1", config)

            group = store.group_snapshots_list("g1")
            expect(group.map { |s| s[:id] }).to contain_exactly(pstruct1[:id], pstruct2[:id])
          end

          it 'deletes the snapshot with the lowest score and adds the new snapshot if it has a higher score than any of the existing snapshots in the group' do
            config = get_config
            config.max_snapshots_per_group = 2
            pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
            pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
            pstruct3 = get_page_struct.tap { |s| s[:root].record_time(40) }

            store.push_snapshot(pstruct1, "g1", config)
            store.push_snapshot(pstruct2, "g1", config)
            store.push_snapshot(pstruct3, "g1", config)

            group = store.group_snapshots_list("g1")
            expect(group.map { |s| s[:id] }).to contain_exactly(pstruct1[:id], pstruct3[:id])
          end
        end
      end

      describe "#{class_name}#snapshots_overview" do
        it 'returns a list of all snapshot groups' do
          config = get_config
          pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
          pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
          pstruct3 = get_page_struct.tap { |s| s[:root].record_time(40) }
          pstruct4 = get_page_struct.tap { |s| s[:root].record_time(70) }
          pstruct5 = get_page_struct.tap { |s| s[:root].record_time(80) }

          store.push_snapshot(pstruct1, "g1", config)
          store.push_snapshot(pstruct2, "g1", config)
          store.push_snapshot(pstruct3, "g2", config)
          store.push_snapshot(pstruct4, "g2", config)
          store.push_snapshot(pstruct5, "g3", config)

          overview = store.snapshots_overview
          g1 = overview.find { |g| g[:name] == "g1" }
          g2 = overview.find { |g| g[:name] == "g2" }
          g3 = overview.find { |g| g[:name] == "g3" }
          expect(g1[:worst_score]).to eq(30)
          expect(g2[:worst_score]).to eq(70)
          expect(g3[:worst_score]).to eq(80)
        end
      end

      describe '#group_snapshots_list' do
        it 'returns a list of all snapshots of the given group' do
          config = get_config
          pstruct1 = get_page_struct.tap { |s| s[:root].record_time(30) }
          pstruct2 = get_page_struct.tap { |s| s[:root].record_time(20) }
          pstruct3 = get_page_struct.tap { |s| s[:root].record_time(40) }
          pstruct4 = get_page_struct.tap { |s| s[:root].record_time(70) }
          pstruct5 = get_page_struct.tap { |s| s[:root].record_time(80) }
          [pstruct1, pstruct2, pstruct3, pstruct4, pstruct5].each_with_index do |s, i|
            s[:started_at] = i
          end

          store.push_snapshot(pstruct1, "g1", config)
          store.push_snapshot(pstruct2, "g1", config)
          store.push_snapshot(pstruct3, "g2", config)
          store.push_snapshot(pstruct4, "g2", config)
          store.push_snapshot(pstruct5, "g3", config)

          g1 = store.group_snapshots_list("g1")
          g2 = store.group_snapshots_list("g2")
          g3 = store.group_snapshots_list("g3")
          expect(g1).to contain_exactly(
            { id: pstruct1[:id], duration: 30, timestamp: 0 },
            { id: pstruct2[:id], duration: 20, timestamp: 1 }
          )
          expect(g2).to contain_exactly(
            { id: pstruct3[:id], duration: 40, timestamp: 2 },
            { id: pstruct4[:id], duration: 70, timestamp: 3 }
          )
          expect(g3).to contain_exactly(
            { id: pstruct5[:id], duration: 80, timestamp: 4 }
          )
        end
      end

      describe "#{class_name}#load_snapshot" do
        it 'loads snapshot of the given id and group name' do
          config = get_config
          pstruct = get_page_struct.tap { |s| s[:root].record_time(30) }
          store.push_snapshot(pstruct, "g1", config)

          loaded_pstruct = store.load_snapshot(pstruct[:id], "g1")
          expect(Rack::MiniProfiler::TimerStruct::Page === loaded_pstruct).to eq(true)
          expect(loaded_pstruct.to_json).to eq(pstruct.to_json)
        end

        it 'returns nil if snapshot is not found' do
          config = get_config
          pstruct = get_page_struct.tap { |s| s[:root].record_time(30) }
          store.push_snapshot(pstruct, "g1", config)

          expect(store.load_snapshot(pstruct[:id], "doesntexist")).to eq(nil)
          expect(store.load_snapshot("doesntexist", "g1")).to eq(nil)
          expect(store.load_snapshot("doesntexist", "doesntexist")).to eq(nil)
        end
      end
    end
  end
end
