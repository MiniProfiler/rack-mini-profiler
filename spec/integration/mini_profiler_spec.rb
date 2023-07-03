# frozen_string_literal: true

require 'rack/test'

describe Rack::MiniProfiler do
  include Rack::Test::Methods

  def app
    @app ||= Rack::Builder.new {
      use Rack::MiniProfiler
      map '/path2/a' do
        run lambda { |env| [200, { 'Content-Type' => 'text/html' }, +'<h1>path1</h1>'] }
      end
      map '/path1/a' do
        run lambda { |env| [200, { 'Content-Type' => 'text/html' }, +'<h1>path2</h1>'] }
      end
      map '/cached-resource' do
        run lambda { |env|
          ims = env['HTTP_IF_MODIFIED_SINCE'] || ""
          if ims.size > 0
            [304, { 'Content-Type' => 'application/json' }, '']
          else
            [200, { 'Content-Type' => 'application/json', 'Cache-Control' => 'original-cache-control' }, '{"name": "Ryan"}']
          end
        }
      end
      map '/post' do
        run lambda { |env| [302, { 'Content-Type' => 'text/html' }, +'<h1>POST</h1>'] }
      end
      map '/html' do
        run lambda { |env| [200, { 'Content-Type' => 'text/html' }, +"<html><BODY><h1>Hi</h1></BODY>\n \t</html>"] }
      end
      map '/explicitly-allowed-html' do
        run lambda { |env|
          Rack::MiniProfiler.authorize_request
          [200, { 'Content-Type' => 'text/html' }, +"<html><BODY><h1>Hi</h1></BODY>\n \t</html>"]
        }
      end
      map '/implicitbody' do
        run lambda { |env| [200, { 'Content-Type' => 'text/html' }, +"<html><h1>Hi</h1></html>"] }
      end
      map '/implicitbodyhtml' do
        run lambda { |env| [200, { 'Content-Type' => 'text/html' }, +"<h1>Hi</h1>"] }
      end
      map '/db' do
        run lambda { |env|
          ::Rack::MiniProfiler.record_sql("I want to be, in a db", 10)
          [200, { 'Content-Type' => 'text/html' }, +'<h1>Hi+db</h1>']
        }
      end
      map '/3ms' do
        run lambda { |env|
          sleep(0.003)
          [200, { 'Content-Type' => 'text/html' }, +'<h1>Hi</h1>']
        }
      end
      map '/explicitly-allowed' do
        run lambda { |env|
          Rack::MiniProfiler.authorize_request
          [200, { 'Content-Type' => 'text/html' }, +'<h1>path1</h1>']
        }
      end
      map '/rails_engine' do
        run lambda { |env|
          env['SCRIPT_NAME'] = '/rails_engine'  # Rails engines do that
          [200, { 'Content-Type' => 'text/html' }, +'<html><h1>Hi</h1></html>']
        }
      end
      map '/under_passenger' do
        run lambda { |env|
          [200, { 'Content-Type' => 'text/html' }, +'<html><h1>and I ride and I ride</h1></html>']
        }
      end
      map '/create' do
        run lambda { |env|
          [201, { 'Content-Type' => 'text/html' }, +'<html><h1>success</h1></html>']
        }
      end
      map '/notallowed' do
        run lambda { |env|
          [403, { 'Content-Type' => 'text/html' }, +'<html><h1>you are not allowed here</h1></html>']
        }
      end
      map '/whoopsie-daisy' do
        run lambda { |env|
          [500, { 'Content-Type' => 'text/html' }, +'<html><h1>whoopsie daisy</h1></html>']
        }
      end
      map '/test-snapshots-custom-fields' do
        run lambda { |env|
          qp = Rack::Utils.parse_nested_query(env['QUERY_STRING'])
          qp.each { |k, v| Rack::MiniProfiler.add_snapshot_custom_field(k, v) }
          [200, { 'Content-Type' => 'text/html' }, +'<html><h1>custom fields</h1></html>']
        }
      end
    }.to_app
  end

  before do
    Rack::MiniProfiler.reset_config
  end

  describe 'with a valid request' do

    before do
      get '/html'
    end

    it 'returns 200' do
      expect(last_response).to be_ok
    end

    it 'has the X-MiniProfiler-Ids header' do
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end

    it 'has only one X-MiniProfiler-Ids header' do
      h = last_response.headers['X-MiniProfiler-Ids']
      ids = h.split(",")
      expect(ids.count).to eq(1)
    end

    it 'has the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(true)
    end

    it 'has a functioning share link' do
      h = last_response.headers['X-MiniProfiler-Ids']
      id = h.split(",")[0]
      get "/mini-profiler-resources/results?id=#{id}"
      expect(last_response).to be_ok
    end

    it 'avoids xss attacks' do
      h = last_response.headers['X-MiniProfiler-Ids']
      _id = h.split(",")[0]
      get "/mini-profiler-resources/results?id=%22%3E%3Cqss%3E"
      expect(last_response).not_to be_ok
      expect(last_response.body).not_to match(/<qss>/)
      expect(last_response.body).to match(/&lt;qss&gt;/)
    end
  end

  it 'works with async-flamegraph' do
    pid = fork do # Avoid polluting main process with stackprof
      require 'stackprof'

      # Should store flamegraph for ?pp=async-flamegraph
      get '/html?pp=async-flamegraph'
      expect(last_response).to be_ok
      id = last_response.headers['X-MiniProfiler-Ids'].split(",")[0]
      get "/mini-profiler-resources/flamegraph?id=#{id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include("var graph = {")

      # Should store flamegraph based on REFERER
      get '/html', nil, { "HTTP_REFERER" => "/origin?pp=async-flamegraph" }
      expect(last_response).to be_ok
      id = last_response.headers['X-MiniProfiler-Ids'].split(",")[0]
      get "/mini-profiler-resources/flamegraph?id=#{id}"
      expect(last_response).to be_ok
      expect(last_response.body).to include("<title>Rack::MiniProfiler Flamegraph</title>")
      expect(last_response.body).to include("var graph = {")

      # Should have correct iframe URL when the base URL changes
      get "/mini-profiler-resources/flamegraph?id=#{id}", nil, { 'SCRIPT_NAME' => '/my/base/url' }
      expect(last_response).to be_ok
      expect(last_response.body).to include("<title>Rack::MiniProfiler Flamegraph</title>")
      expect(last_response.body).to include("iframeUrl = '/my/base/url/mini-profiler-resources/speedscope/")

      # Should not store/return flamegraph for regular requests
      get '/html'
      expect(last_response).to be_ok
      id = last_response.headers['X-MiniProfiler-Ids'].split(",")[0]
      get "/mini-profiler-resources/flamegraph?id=#{id}"
      expect(last_response.status).to eq(404)
    end

    Process.wait(pid)
    expect($?.exitstatus).to eq(0)
  end

  describe 'with an implicit body tag' do

    before do
      get '/implicitbody'
    end

    it 'has the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'with implicit body and html tags' do

    before do
      get '/implicitbodyhtml'
    end

    it 'does not include the JS in the body' do
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(false)
    end

  end

  describe 'with a SCRIPT_NAME' do

    before do
      get '/html', nil, 'SCRIPT_NAME' => '/test'
    end

    it 'has the JS in the body with the correct path' do
      expect(last_response.body.include?('/test/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'within a rails engine' do

    before do
      get '/rails_engine'
    end

    it 'include the correct JS in the body' do
      expect(last_response.body.include?('/rails_engine/mini-profiler-resources/includes.js')).not_to be(true)
      expect(last_response.body.include?('src="/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'under passenger' do

    before do
      ENV['PASSENGER_BASE_URI'] = '/under_passenger'
    end

    after do
      ENV['PASSENGER_BASE_URI'] = nil
    end

    it 'include the correct JS in the body' do
      get '/under_passenger'
      expect(last_response.body.include?('src="/under_passenger/mini-profiler-resources/includes.js')).to be(true)
    end

  end

  describe 'configuration' do
    it "should remove caching headers by default" do
      get '/cached-resource'
      expect(last_response.headers['X-MiniProfiler-Original-Cache-Control']).to eq('original-cache-control')
      expect(last_response.headers['Cache-Control']).to include('no-store')
    end

    it "should not store the original cache header if not set" do
      get '/html'
      expect(last_response.headers).to_not have_key('X-MiniProfiler-Original-Cache-Control')
    end

    it "should strip if-modified-since on the way in" do
      old_time = 1409326086
      get '/cached-resource', {}, 'HTTP_IF_MODIFIED_SINCE' => old_time
      expect(last_response.status).to equal(200)
    end

    describe 'with hotwire turbo drive support enabled' do
      before do
        Rack::MiniProfiler.config.enable_hotwire_turbo_drive_support = true
      end

      it 'should define data-turbo-permanent as true' do
        get '/html'
        expect(last_response.body).to include('data-turbo-permanent="true"')
      end
    end

    describe 'with caching re-enabled' do
      before :each do
        Rack::MiniProfiler.config.disable_caching = false
      end

      it "should strip if-modified-since on the way in" do
        old_time = 1409326086
        get '/cached-resource', {}, 'HTTP_IF_MODIFIED_SINCE' => old_time
        expect(last_response.status).to equal(304)
      end

      it "should be able to re-enable caching" do
        get '/cached-resource'
        expect(last_response.headers['X-MiniProfiler-Original-Cache-Control']).to eq('original-cache-control')
        expect(last_response.headers['Cache-Control']).not_to include('no-store')
      end
    end

    it "doesn't add MiniProfiler if the callback fails" do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env| false }
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end

    it "skips paths listed" do
      Rack::MiniProfiler.config.skip_paths = ['/path/', '/path2/']
      get '/path2/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
      get '/path1/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end

    it "skip_paths can contain regular expressions" do
      Rack::MiniProfiler.config.skip_paths = [/path[^1]/]
      get '/path2/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
      get '/path1/a'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end

    it 'disables default functionality' do
      Rack::MiniProfiler.config.enabled = false
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end
  end

  def load_prof(response)
    id = response.headers['X-MiniProfiler-Ids']
    id = id.split(",")[0]
    Rack::MiniProfiler.config.storage_instance.load(id)
  end

  describe 'special options' do
    it "omits db backtrace if requested" do
      get '/db?pp=no-backtrace'
      prof = load_prof(last_response)
      stack = prof[:root][:sql_timings][0][:stack_trace_snippet]
      expect(stack).to be_nil
    end

    it 'disables functionality if requested' do
      get '/html?pp=disable'
      expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
    end

    context 'when disabled' do
      before(:each) do
        get '/html?pp=disable'
        get '/html'
        expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
      end

      it 're-enables functionality if requested' do
        get '/html?pp=enable'
        expect(last_response.body).to include('/mini-profiler-resources/includes.js')
      end

      it "does not re-enable functionality if not explicitly allowed" do
        Rack::MiniProfiler.config.authorization_mode = :allow_authorized
        get '/html?pp=enable'
        get '/html?pp=enable'
        expect(last_response.body).not_to include('/mini-profiler-resources/includes.js')
      end

      it "re-enabled functionality if explicitly allowed" do
        Rack::MiniProfiler.config.authorization_mode = :allow_authorized
        get '/explicitly-allowed-html?pp=enable'
        get '/explicitly-allowed-html?pp=enable'
        expect(last_response.body).to include('/mini-profiler-resources/includes.js')
      end
    end

    describe 'env dump' do
      it 'works when advanced tools are enabled' do
        Rack::MiniProfiler.config.enable_advanced_debugging_tools = true
        get '/html?pp=env'

        expect(last_response.body).to include('QUERY_STRING')
        expect(last_response.body).to include('CONTENT_LENGTH')
      end
    end
  end

  describe 'POST followed by GET' do
    it "should end up with 2 ids" do
      post '/post'
      get '/html'

      ids = last_response.headers['X-MiniProfiler-Ids']
      expect(ids.split(",").length).to eq(2)
    end
  end

  describe 'authorization mode :allow_authorized' do
    before do
      Rack::MiniProfiler.config.authorization_mode = :allow_authorized
    end

    it "should ban requests that are not explicitly allowed" do
      get '/html'
      expect(last_response.headers['X-MiniProfiler-Ids']).to be_nil
    end

    it "should allow requests that are explicitly allowed" do
      get '/explicitly-allowed'
      # second time will ensure cookie is set
      # first time around there is no cookie, so no profiling
      get '/explicitly-allowed'
      expect(last_response.headers['X-MiniProfiler-Ids']).not_to be_nil
    end
  end

  describe 'gc profiler' do
    it "should return a report" do
      get '/html?pp=profile-gc'
      expect(last_response.header['Content-Type']).to include('text/plain')
    end
  end

  describe 'error handling when storage_instance fails to save' do
    it "should recover gracefully" do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env| true }
      allow_any_instance_of(Rack::MiniProfiler::MemoryStore).to receive(:save) { raise "This error" }
      expect(Rack::MiniProfiler.config.storage_failure).to receive(:call)
      get '/html'
    end
  end

  describe 'when profiler is disabled by default' do
    before(:each) do
      Rack::MiniProfiler.config.enabled = false
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
    end

    it 'functionality can be re-enabled' do
      get '/html?pp=enable'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
      get '/html'
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(true)
    end
  end

  context 'snapshots sampling' do
    before(:each) do
      Rack::MiniProfiler.config.tap do |c|
        c.authorization_mode = :allow_authorized
        c.snapshot_every_n_requests = 1
      end
    end

    after(:each) do
      Rack::MiniProfiler.reset_config
    end

    it 'does not take snapshots of paths in skip_paths' do
      config = Rack::MiniProfiler.config
      config.skip_paths = ['/path2/a']
      get '/path2/a'
      expect(Rack::MiniProfiler.config.storage_instance.snapshots_overview).to eq([])
    end

    it 'takes snapshots of requests that fail the pre_authorize_cb check' do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env| false }
      get '/path2/a'
      data = Rack::MiniProfiler.config.storage_instance.snapshots_overview
      expect(data.size).to eq(1)
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(false)
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
      expect(data[0][:name]).to eq("GET /path2/a")
    end

    it 'takes snapshots of requests that do not have valid token in cookie' do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env| true }
      get '/path2/a'
      data = Rack::MiniProfiler.config.storage_instance.snapshots_overview
      expect(last_response.body.include?('/mini-profiler-resources/includes.js')).to be(false)
      expect(last_response.headers.has_key?('X-MiniProfiler-Ids')).to be(false)
      expect(data.size).to eq(1)
    end

    it 'does not take snapshots of requests that have valid token in cookie' do
      Rack::MiniProfiler.config.pre_authorize_cb = lambda { |env| true }
      get '/explicitly-allowed-html'
      cookies = last_response.set_cookie_header
      get '/path2/a', nil, { cookie: cookies } # no snapshot here
      data = Rack::MiniProfiler.config.storage_instance.snapshots_overview
      expect(data.size).to eq(1)
      expect(data[0][:name]).to eq("GET /explicitly-allowed-html")
    end

    it 'respects snapshot_every_n_requests config' do
      Rack::MiniProfiler.config.snapshot_every_n_requests = 2
      get '/path2/a'
      get '/path2/a'
      get '/path2/a'
      get '/path2/a'
      store = Rack::MiniProfiler.config.storage_instance
      groups = store.snapshots_overview
      expect(groups.size).to eq(1)
      group_name = "GET /path2/a"
      expect(groups[0][:name]).to eq(group_name)
      expect(store.snapshots_group(group_name).size).to eq(2)
    end

    it 'does not take snapshots for non-2xx requests' do
      Rack::MiniProfiler.config.snapshot_every_n_requests = 1
      get '/path/that/doesnot/exist' # 404
      get '/post' # 302
      get '/notallowed' # 403
      get '/whoopsie-daisy' # 500
      post '/create' # 201
      groups = Rack::MiniProfiler.config.storage_instance.snapshots_overview
      expect(groups.size).to eq(1)
      expect(groups[0][:name]).to eq("POST /create")
    end

    it 'custom fields are reset between requests' do
      get '/test-snapshots-custom-fields?field1=value1&field2=value2'
      store = Rack::MiniProfiler.config.storage_instance

      group_name = "GET /test-snapshots-custom-fields"

      id1 = store.snapshots_group(group_name).first[:id]
      snapshot1 = store.load_snapshot(id1, group_name)

      get '/test-snapshots-custom-fields?field3=value3&field4=value4'
      id2 = store.snapshots_group(group_name).find { |s| s[:id] != id1 }[:id]
      snapshot2 = store.load_snapshot(id2, group_name)

      expect(snapshot1[:custom_fields]).to eq(
        { "field1" => "value1", "field2" => "value2" }
      )
      expect(snapshot2[:custom_fields]).to eq(
        { "field3" => "value3", "field4" => "value4" }
      )
    end
  end

  context 'snapshots page' do
    it 'allows only authorized users to access it' do
      base_url = Rack::MiniProfiler.config.base_url_path
      Rack::MiniProfiler.config.authorization_mode = :allow_authorized
      get "#{base_url}snapshots"
      expect(last_response.status).to eq(404)
      expect(last_response.body).to eq("Not Found: /mini-profiler-resources/snapshots")

      get '/explicitly-allowed-html'
      cookies = last_response.set_cookie_header
      get "#{base_url}snapshots", nil, { cookie: cookies }
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('id="snapshots-data"')
    end

    it 'without group_name param it sends groups list in response' do
      base_url = Rack::MiniProfiler.config.base_url_path
      # initial request to initialize storage_instance
      get "#{base_url}snapshots"

      store = Rack::MiniProfiler.config.storage_instance
      struct = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => '/some/path/here',
        'REQUEST_METHOD' => 'POST'
      })
      struct[:root].record_time(1342.314242)
      group_name = "POST /some/path/here"
      store.push_snapshot(struct, group_name, Rack::MiniProfiler.config)
      get "#{base_url}snapshots"
      expect(last_response.body).to include('id="snapshots-data"')
      expect(last_response.body).to include("/some/path/here")
      expect(last_response.body).to include(group_name)
      expect(last_response.body).to include("1342.314242")
    end

    it 'with group_name params it sends a list of snapshots of the given group' do
      base_url = Rack::MiniProfiler.config.base_url_path
      # initial request to initialize storage_instance
      get "#{base_url}snapshots"

      store = Rack::MiniProfiler.config.storage_instance
      struct1 = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => '/some/path/here',
        'REQUEST_METHOD' => 'POST'
      })
      struct1[:root].record_time(1342.314242)

      struct2 = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => '/another/path/here',
        'REQUEST_METHOD' => 'DELETE'
      })
      struct2[:root].record_time(8342.08342)

      struct3 = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => '/another/path/here',
        'REQUEST_METHOD' => 'DELETE'
      })
      struct3[:root].record_time(3084.803185)

      store.push_snapshot(
        struct1,
        "POST /some/path/here",
        Rack::MiniProfiler.config
      )
      store.push_snapshot(
        struct2,
        "DELETE /another/path/here",
        Rack::MiniProfiler.config
      )
      store.push_snapshot(
        struct3,
        "DELETE /another/path/here",
        Rack::MiniProfiler.config
      )

      qs = Rack::Utils.build_query({ group_name: "DELETE /another/path/here" })
      get "#{base_url}snapshots?#{qs}"
      expect(last_response.body).to include("<title>Rack::MiniProfiler Snapshots</title>")
      expect(last_response.body).to include('id="snapshots-data"')
      expect(last_response.body).to include(struct2[:id])
      expect(last_response.body).to include(struct3[:id])
      expect(last_response.body).to include("DELETE /another/path/here")
      expect(last_response.body).to include("3084.803185")
      expect(last_response.body).to include("8342.08342")
      expect(last_response.body).not_to include(struct1[:id])
      expect(last_response.body).not_to include("1342.314242")
    end

    it 'individual snapshot can be viewed' do
      base_url = Rack::MiniProfiler.config.base_url_path
      # initial request to initialize storage_instance
      get "#{base_url}snapshots"

      store = Rack::MiniProfiler.config.storage_instance
      struct = Rack::MiniProfiler::TimerStruct::Page.new({
        'PATH_INFO' => '/some/path/here',
        'REQUEST_METHOD' => 'POST'
      })
      struct[:root].record_time(1342.314242)
      group_name = "POST /some/path/here"
      store.push_snapshot(struct, group_name, Rack::MiniProfiler.config)

      get "#{base_url}results?id=#{struct[:id]}&group=#{group_name}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include(struct[:id])
      expect(last_response.body).to include("1342.314242")
    end

    it 'when snapshot is not found a 404 response is given' do
      base_url = Rack::MiniProfiler.config.base_url_path
      get "#{base_url}results?id=nonsenseidhere&group=groupdoesnotexist"
      expect(last_response.status).to eq(404)
      expect(last_response.body).to eq("Snapshot with id 'nonsenseidhere' not found")

      get "#{base_url}results?id=%22%3E%3Cqss%3E&group=groupdoesnotexist"
      expect(last_response.status).to eq(404)
      expect(last_response.body).to eq("Snapshot with id '&quot;&gt;&lt;qss&gt;' not found"), "id should be escaped to prevent XSS"
    end
  end
end
