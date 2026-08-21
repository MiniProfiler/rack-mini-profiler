# frozen_string_literal: true

require 'active_record'
require 'rails'
require File.expand_path('../../../lib/mini_profiler_rails/railtie', __FILE__)

describe 'Active Record SQL profiling' do
  before do
    ENV['RAILS_ENV'] = 'test'
    Rails.logger = Logger.new(IO::NULL)

    unless Rack::MiniProfilerRails.instance_variable_defined?(:@already_initialized)
      middleware = Object.new
      def middleware.insert(*) = nil

      app = Struct.new(:config, :middleware).new(Object.new, middleware)
      Rack::MiniProfiler.subscribe_sql_active_record = true
      Rack::MiniProfilerRails.initialize!(app)
    end

    ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
    ActiveRecord::Schema.define do
      create_table :sql_bind_users do |table|
        table.string :name
      end
    end

    stub_const('SqlBindUser', Class.new(ActiveRecord::Base) do
      self.table_name = 'sql_bind_users'
    end)

    SqlBindUser.create!(name: 'Alice')

    Rack::MiniProfiler.reset_config
    Rack::MiniProfiler.config.max_sql_param_length = nil
    Rack::MiniProfiler.create_current
  end

  after do
    Rack::MiniProfiler.current = nil
    ActiveRecord::Base.connection_pool.disconnect!
  end

  it 'profiles find_by_sql queries with unnamed bind parameters' do
    users = SqlBindUser.find_by_sql(
      'SELECT * FROM sql_bind_users WHERE name = ?',
      ['Alice']
    )

    expect(users.map(&:name)).to eq(['Alice'])
    expect(Rack::MiniProfiler.current.current_timer.sql_timings.last[:parameters]).to eq([['param', 'Alice']])
  end

  it 'profiles unnamed bind values that respond to name but not value' do
    users = SqlBindUser.find_by_sql(
      'SELECT * FROM sql_bind_users WHERE name = ?',
      [:Alice]
    )

    expect(users.map(&:name)).to eq(['Alice'])
    expect(Rack::MiniProfiler.current.current_timer.sql_timings.last[:parameters]).to eq([['param', :Alice]])
  end
end
