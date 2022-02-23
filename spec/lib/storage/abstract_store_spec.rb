# frozen_string_literal: true

describe Rack::MiniProfiler::AbstractStore do
  TestStore = Class.new(Rack::MiniProfiler::AbstractStore) do
    def fetch_snapshots_overview
      overview = {}
      snapshots.shuffle.each do |ss|
        group_name = "#{ss[:request_method]} #{ss[:request_path]}"
        group = overview[group_name]
        if group
          group[:worst_score] = ss.duration_ms if ss.duration_ms > group[:worst_score]
          group[:best_score] = ss.duration_ms if ss.duration_ms < group[:best_score]
          group[:snapshots_count] += 1
        else
          overview[group_name] = {
            worst_score: ss.duration_ms,
            best_score: ss.duration_ms,
            snapshots_count: 1
          }
        end
      end
      overview
    end

    def fetch_snapshots_group(group_name)
      snapshots.select do |snapshot|
        group_name == "#{snapshot[:request_method]} #{snapshot[:request_path]}"
      end
    end

    private

    def snapshots
      @snapshots ||= [
        get_page_struct("topics#index", "GET", 50.314, 4, f1: 15),
        get_page_struct("topics#delete", "DELETE", 15.424, 7, f2: 'val'),
        get_page_struct("topics#delete", "DELETE", 63.984, 13, f4: '1'),
        get_page_struct("users#delete", "DELETE", 24.243, 9, f5: 98),
        get_page_struct("users#delete", "DELETE", 831.4232, 15, f3: 82),
        get_page_struct("/some/path", "POST", 75.3793, 20, f6: 10)
      ]
    end

    def get_page_struct(path, method, duration, sql_count, **custom_fields)
      page = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => path,
        'REQUEST_METHOD' => method
      })
      page[:root].record_time(duration)
      page[:sql_count] = sql_count
      page[:custom_fields] = custom_fields
      page
    end
  end

  let(:test_store) { TestStore.new }

  describe '#snapshots_overview' do
    let(:groups) { test_store.snapshots_overview }

    it 'returns an array of hashes' do
      groups.each do |group|
        expect(group).to be_instance_of(Hash)
        expect(group.keys).to contain_exactly(:worst_score, :best_score, :name, :snapshots_count)
      end
    end

    it 'sorts groups from worst to best' do
      expect(groups.map { |g| g[:worst_score] }).to eq([831.4232, 75.3793, 63.984, 50.314])
    end
  end

  describe '#snapshots_group' do
    let(:g1) { test_store.snapshots_group("DELETE users#delete") }
    let(:g2) { test_store.snapshots_group("POST /some/path") }
    let(:g3) { test_store.snapshots_group("DELETE topics#delete") }
    let(:g4) { test_store.snapshots_group("GET topics#index") }

    it 'finds group by name' do
      expect(g1.size).to eq(2)
      expect(g2.size).to eq(1)
      expect(g3.size).to eq(2)
      expect(g4.size).to eq(1)
    end

    it 'sorts snapshots from worst to best' do
      expect(g1.map { |s| s[:duration] }).to eq([831.4232, 24.243])
      expect(g2.map { |s| s[:duration] }).to eq([75.3793])
      expect(g3.map { |s| s[:duration] }).to eq([63.984, 15.424])
      expect(g4.map { |s| s[:duration] }).to eq([50.314])
    end

    it 'includes sql_count with each snapshot' do
      expect(g1.map { |s| s[:sql_count] }).to eq([15, 9])
      expect(g2.map { |s| s[:sql_count] }).to eq([20])
      expect(g3.map { |s| s[:sql_count] }).to eq([13, 7])
      expect(g4.map { |s| s[:sql_count] }).to eq([4])
    end

    it 'includes custom_fields with each snapshot' do
      expect(g1.map { |s| s[:custom_fields] }).to eq([{ f3: 82 }, { f5: 98 }])
      expect(g2.map { |s| s[:custom_fields] }).to eq([{ f6: 10 }])
      expect(g3.map { |s| s[:custom_fields] }).to eq([{ f4: '1' }, { f2: 'val' }])
      expect(g4.map { |s| s[:custom_fields] }).to eq([{ f1: 15 }])
    end
  end
end
