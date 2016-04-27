require 'spec_helper'


describe Rack::MiniProfiler::TimerStruct::Sql do
  before do
    @page = Rack::MiniProfiler::TimerStruct::Page.new({})
  end

  describe 'valid sql timer' do
    before do
      @sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
    end

    [
      :execute_type, :formatted_command_string, :stack_trace_snippet, :start_milliseconds, :duration_milliseconds,
      :first_fetch_duration_milliseconds, :is_duplicate
    ].each do |attr_type|
      it "has an #{attr_type}" do
        @sql[attr_type].should_not be_nil
      end
    end
  end



  describe 'backtrace' do
    it 'has a snippet' do
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should_not be nil
    end

    it 'includes rspec in the trace (default is no filter)' do
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should match /rspec/
    end

    it "doesn't include rspec if we filter for only app" do
      Rack::MiniProfiler.config.backtrace_includes = [/\/app/]
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should_not match /rspec/
    end

    it "includes rspec if we filter for it" do
      Rack::MiniProfiler.config.backtrace_includes = [/\/(app|rspec)/]
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should match /rspec/
    end

    it "includes rspec if we filter for it along with something else" do
      Rack::MiniProfiler.config.backtrace_includes = [/rspec/, /something_else/]
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should match /rspec/
    end

    it "ignores rspec if we specifically ignore it" do
      Rack::MiniProfiler.config.backtrace_ignores = [/\/rspec/]
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should_not match /rspec/
    end

    it "ignores rspec if we specifically ignore it along with something else" do
      Rack::MiniProfiler.config.backtrace_ignores = [/\/rspec/, /something_else/]
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should_not match /rspec/
    end

    it "should omit the backtrace if the query takes less than the threshold time" do
      Rack::MiniProfiler.config.backtrace_threshold_ms = 100
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 50, @page, nil)
      sql[:stack_trace_snippet].should be nil
    end

    it "should not omit the backtrace if the query takes more than the threshold time" do
      Rack::MiniProfiler.config.backtrace_threshold_ms = 100
      sql = Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil)
      sql[:stack_trace_snippet].should_not be nil
    end
  end

  describe "#params" do
    let(:sample_params) { [["name", "admin"], ["value", "string with more than 20"], ["limit", 1]] }
    #def initialize(query, duration_ms, page, parent, params = nil, skip_backtrace = false, full_backtrace = false)
    it "skips parameters by default" do
      Rack::MiniProfiler.config.max_sql_param_length = 0
      sql = sql_with_params(sample_params)
      sql[:parameters].should be nil
    end

    it "stores parameters untouched" do
      Rack::MiniProfiler.config.max_sql_param_length = nil
      sql = sql_with_params(sample_params)
      sql[:parameters].should eq sample_params
    end

    it "truncates string parameters" do
      Rack::MiniProfiler.config.max_sql_param_length = 6
      sql = sql_with_params(sample_params)
      sql[:parameters].should eq [["name", "admin"], ["value", "string"], ["limit", 1]]
    end

    def sql_with_params(params)
      Rack::MiniProfiler::TimerStruct::Sql.new("SELECT * FROM users", 200, @page, nil, params)
    end
  end
end
