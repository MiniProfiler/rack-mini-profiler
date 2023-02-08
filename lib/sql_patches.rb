# frozen_string_literal: true

class SqlPatches
  def self.patch_rails?
    ::Rack::MiniProfiler.patch_rails?
  end

  def self.sql_patches
    patches = []

    patches << 'mysql2' if defined?(Mysql2::Client) && Mysql2::Client.class == Class
    patches << 'pg' if defined?(PG::Result) && PG::Result.class == Class
    patches << 'oracle_enhanced' if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) && ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class == Class &&
                                    SqlPatches.correct_version?('~> 1.5.0', ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) &&
                                    patch_rails?
    # if the adapters were directly patched, don't patch again
    if !patches.empty?
      Rack::MiniProfiler.subscribe_sql_active_record = false
      return patches
    end
    patches << 'sequel' if defined?(Sequel::Database) && Sequel::Database.class == Class
    patches << 'activerecord' if defined?(ActiveRecord) && ActiveRecord.class == Module && patch_rails?
    Rack::MiniProfiler.subscribe_sql_active_record = patches.empty? && !patch_rails?
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
    warn("SqlPatches.patch is deprecated. Please patch libraries manually.")

    patch_files.each do |patch_file|
      require "mini_profiler/patches/db/#{patch_file}"
    end
  end
end
