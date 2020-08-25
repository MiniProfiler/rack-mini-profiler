# frozen_string_literal: true

describe Rack::MiniProfiler::AbstractStore do
  def get_config
    Rack::MiniProfiler::Config.default
  end

  test_store = Class.new(Rack::MiniProfiler::AbstractStore) do
    def fetch_snapshots(batch_size: 3, &blk)
      blk.call([
        get_page_struct("topics#index", "GET", 50.314),
        get_page_struct("topics#delete", "DELETE", 15.424),
        get_page_struct("users#delete", "DELETE", 831.4232)
      ])
      blk.call([
        get_page_struct("topics#delete", "DELETE", 63.984),
        get_page_struct("users#delete", "DELETE", 24.243),
        get_page_struct("/some/path", "POST", 75.3793)
      ])
    end

    private

    def get_page_struct(path, method, duration)
      page = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => path,
        'REQUEST_METHOD' => method
      })
      page[:root].record_time(duration)
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
  end
end
