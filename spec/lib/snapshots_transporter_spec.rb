# frozen_string_literal: true

describe Rack::MiniProfiler::SnapshotsTransporter do
  let(:url) { 'http://example.com/dest' }
  let(:transporter) do
    config = Rack::MiniProfiler.config
    config.snapshots_transport_destination_url = url
    config.snapshots_transport_auth_key = 'somepasswordhere'
    transporter = described_class.new(config)
    transporter.instance_variable_set(:@testing, true)
    transporter.max_buffer_size = 4
    transporter
  end

  it '#ship keeps buffer size at max_buffer_size' do
    snapshots = 5.times.to_a.map do
      Rack::MiniProfiler::TimerStruct::Page.new({})
    end
    snapshots.each { |s| transporter.ship(s) }
    expect(transporter.buffer.size).to eq(4)
    expect(transporter.buffer).to eq(snapshots[1..4])
  end

  it '#flush_buffer clears buffer if response is 200' do
    snapshot = Rack::MiniProfiler::TimerStruct::Page.new({})
    stub_request(:post, url)
      .with(
        body: { snapshots: [snapshot] }.to_json,
        headers: { 'Mini-Profiler-Transport-Auth' => 'somepasswordhere' }
      )
      .to_return(status: 200, body: "", headers: {})
    transporter.ship(snapshot)
    transporter.flush_buffer
    expect(transporter.buffer.size).to eq(0)
  end

  it '#flush_buffer does not clear buffer if response is not 200' do
    stub_request(:post, url).to_return(status: 500, body: "", headers: {})
    transporter.ship(Rack::MiniProfiler::TimerStruct::Page.new({}))
    transporter.flush_buffer
    expect(transporter.buffer.size).to eq(1)
  end
end
