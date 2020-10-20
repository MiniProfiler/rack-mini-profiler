# frozen_string_literal: true

class SqlPatches
  def self.correct_version?(required_version, klass)
    Gem::Dependency.new('', required_version).match?('', klass::VERSION)
  rescue NameError
    false
  end

  def self.record_sql(statement, parameters = nil, &block)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    record =
      ::Rack::MiniProfiler.record_sql(
        statement,
        elapsed_time(start),
        parameters
      )
    [result, record]
  end

  def self.should_measure?
    current = ::Rack::MiniProfiler.current
    (current && current.measure)
  end

  def self.elapsed_time(start_time)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time).to_f * 1000)
      .round(1)
  end

  def self.patch_rails?
    ::Rack::MiniProfiler.patch_rails?
  end

  def self.sql_patches
    patches = []

    if defined?(Mysql2::Client) && Mysql2::Client.class == Class
      patches << 'mysql2'
    end
    patches << 'pg' if defined?(PG::Result) && PG::Result.class == Class
    if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) &&
         ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class ==
           Class &&
         SqlPatches.correct_version?(
           '~> 1.5.0',
           ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter
         ) && patch_rails?
      patches << 'oracle_enhanced'
    end

    # if the adapters were directly patched, don't patch again
    if !patches.empty?
      Rack::MiniProfiler.subscribe_sql_active_record = false
      return patches
    end
    if defined?(Sequel::Database) && Sequel::Database.class == Class
      patches << 'sequel'
    end
    if defined?(ActiveRecord) && ActiveRecord.class == Module && patch_rails?
      patches << 'activerecord'
    end
    Rack::MiniProfiler.subscribe_sql_active_record =
      patches.empty? && !patch_rails?
    patches
  end

  def self.other_patches
    patches = []
    if defined?(Mongo::Server::Connection) && Mongo.class == Module
      patches << 'mongo'
    end
    patches << 'moped' if defined?(Moped::Node) && Moped::Node.class == Class
    if defined?(Plucky::Query) && Plucky::Query.class == Class
      patches << 'plucky'
    end
    if defined?(RSolr::Connection) && RSolr::Connection.class == Class &&
         RSolr::VERSION[0] != '0'
      patches << 'rsolr'
    end
    patches << 'nobrainer' if defined?(NoBrainer) && NoBrainer.class == Module
    patches << 'riak' if defined?(Riak) && Riak.class == Module
    if defined?(Neo4j::Core) && Neo4j::Core::Query.class == Class
      patches << 'neo4j'
    end
    patches
  end

  def self.all_patch_files
    env_var = ENV['RACK_MINI_PROFILER_PATCH']
    return [] if env_var == 'false'
    env_var ? env_var.split(',').map(&:strip) : sql_patches + other_patches
  end

  def self.patch(patch_files = all_patch_files)
    patch_files.each { |patch_file| require "patches/db/#{patch_file}" }
  end
end

SqlPatches.patch
