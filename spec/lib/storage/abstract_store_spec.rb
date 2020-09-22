# frozen_string_literal: true

describe Rack::MiniProfiler::AbstractStore do
  def get_config
    Rack::MiniProfiler::Config.default
  end

  test_store = Class.new(Rack::MiniProfiler::AbstractStore) do
    def fetch_snapshots(batch_size: 3, &blk)
      blk.call([
        get_page_struct("topics#index", "GET", 50.314, 4, f1: 15),
        get_page_struct("topics#delete", "DELETE", 15.424, 7, f2: 'val'),
        get_page_struct("topics#delete", "DELETE", 63.984, 13, f4: '1')
      ])
      blk.call([
        get_page_struct("users#delete", "DELETE", 24.243, 9, f5: 98),
        get_page_struct("users#delete", "DELETE", 831.4232, 15, f3: 82),
        get_page_struct("/some/path", "POST", 75.3793, 20, f6: 10)
      ])
    end

    private

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
  end.new

  describe '#snapshot_groups_overview' do
    let(:groups) { test_store.snapshot_groups_overview }

    it 'groups snapshots by request method and request path' do
      expect(groups.size).to eq(4)
      expect(groups.map { |g| g[:name] }).to eq(%w[
        DELETE\ users#delete
        POST\ /some/path
        DELETE\ topics#delete
        GET\ topics#index
      ])
    end

    it 'sorts groups from worst to best' do
      expect(groups.map { |g| g[:worst_score] }).to eq([831.4232, 75.3793, 63.984, 50.314])
    end

    it 'includes best_score' do
      expect(groups.map { |g| g[:best_score] }).to eq([24.243, 75.3793, 15.424, 50.314])
    end
  end

  describe '#find_snapshots_group' do
    let(:g1) { test_store.find_snapshots_group("DELETE users#delete") }
    let(:g2) { test_store.find_snapshots_group("POST /some/path") }
    let(:g3) { test_store.find_snapshots_group("DELETE topics#delete") }
    let(:g4) { test_store.find_snapshots_group("GET topics#index") }

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
