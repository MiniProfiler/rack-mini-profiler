class SqlPatches
  def self.correct_version?(required_version, klass)
    Gem::Dependency.new('', required_version).match?('', klass::VERSION)
  rescue NameError
    false
  end

  def self.record_sql(statement, parameters = nil, &block)
    start  = Time.now
    result = yield
    record = ::Rack::MiniProfiler.record_sql(statement, elapsed_time(start), parameters)
    return result, record
  end

  def self.should_measure?
    current = ::Rack::MiniProfiler.current
    (current && current.measure)
  end

  def self.elapsed_time(start_time)
    ((Time.now - start_time).to_f * 1000).round(1)
  end

  def self.sql_patches
    patches = []

    patches << 'mysql2' if defined?(Mysql2::Client) && Mysql2::Client.class == Class
    patches << 'pg' if defined?(PG::Result) && PG::Result.class == Class
    patches << 'oracle_enhanced' if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) && ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class == Class &&
                                    SqlPatches.correct_version?('~> 1.5.0', ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
    # if the adapters were directly patched, don't patch again
    return patches unless patches.empty?
    patches << 'sequel' if defined?(Sequel::Database) && Sequel::Database.class == Class
    patches << 'activerecord' if defined?(ActiveRecord) && ActiveRecord.class == Module

    patches
  end

  def self.other_patches
    patches = []
    patches << 'mongo' if defined?(Mongo::Server::Connection) && Mongo.class == Module
    patches << 'moped' if defined?(Moped::Node) && Moped::Node.class == Class
    patches << 'plucky' if defined?(Plucky::Query) && Plucky::Query.class == Class
    patches << 'rsolr' if defined?(RSolr::Connection) && RSolr::Connection.class == Class && RSolr::VERSION[0] != "0"
    patches << 'nobrainer' if defined?(NoBrainer) && NoBrainer.class == Module
    patches << 'riak' if defined?(Riak) && Riak.class == Module
    patches << 'neo4j' if defined?(Neo4j::Core) && Neo4j::Core::Query.class == Class
    patches
  end

  def self.all_patch_files
    env_var = ENV["RACK_MINI_PROFILER_PATCH"]
    return [] if env_var == "false"
    env_var ? env_var.split(",").map(&:strip) : sql_patches + other_patches
  end

  def self.patch(patch_files = all_patch_files)
    patch_files.each do |patch_file|
      require "patches/db/#{patch_file}"
    end
  end
end

SqlPatches.patch
