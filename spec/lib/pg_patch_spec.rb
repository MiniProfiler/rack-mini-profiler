# frozen_string_literal: true

require 'spec_helper'

describe SqlPatches do
  context 'with the PostgreSQL patch' do
    around do |example|
      max_sql_param_length = Rack::MiniProfiler.config.max_sql_param_length
      Rack::MiniProfiler.config.max_sql_param_length = nil
      example.run
    ensure
      Rack::MiniProfiler.config.max_sql_param_length = max_sql_param_length
    end

    it 'records parameters passed to exec_params' do
      result_class = Class.new do
        def each(*) = nil
        def values(*) = nil
      end

      connection_class = Class.new do
        define_method(:exec) { |*| result_class.new }
        alias_method :async_exec, :exec
        alias_method :exec_prepared, :exec
        alias_method :send_query_prepared, :exec
        alias_method :prepare, :exec
        alias_method :exec_params, :exec
      end

      stub_const('PG', Module.new)
      PG.const_set(:VERSION, '1.1.0')
      PG.const_set(:Result, result_class)
      PG.const_set(:Connection, connection_class)

      require_relative '../../lib/patches/db/pg/alias_method'

      allow(SqlPatches).to receive(:should_measure?).and_return(true)
      expect(Rack::MiniProfiler).to receive(:record_sql).with(
        'SELECT * FROM users WHERE name = $1 AND active = $2',
        kind_of(Numeric),
        [['param', 'Alice'], ['param', true]]
      )

      PG::Connection.new.exec_params(
        'SELECT * FROM users WHERE name = $1 AND active = $2',
        ['Alice', true]
      )
    end
  end
end
