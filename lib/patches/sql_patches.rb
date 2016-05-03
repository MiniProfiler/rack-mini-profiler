class SqlPatches
  def self.unpatched?
    !patched?
  end

  def self.patched?
    @patched
  end

  def self.patched=(val)
    @patched = val
  end

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
end

require 'patches/db/mysql2'           if defined?(Mysql2::Client) && Mysql2::Client.class == Class
require 'patches/db/pg'               if defined?(PG::Result) && PG::Result.class == Class
require 'patches/db/oracle_enhanced'  if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) && ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter.class == Class && SqlPatches.correct_version?('~> 1.5.0', ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
require 'patches/db/mongo'            if defined?(Mongo::Server::Connection) && Mongo.class == Module
require 'patches/db/moped'            if defined?(Moped::Node) && Moped::Node.class == Class
require 'patches/db/plucky'           if defined?(Plucky::Query) && Plucky::Query.class == Class
require 'patches/db/rsolr'            if defined?(RSolr::Connection) && RSolr::Connection.class == Class && RSolr::VERSION[0] != "0"
require 'patches/db/sequel'           if SqlPatches.unpatched? && defined?(Sequel::Database) && Sequel::Database.class == Class
require 'patches/db/activerecord'     if SqlPatches.unpatched? && defined?(ActiveRecord) && ActiveRecord.class == Module
require 'patches/db/nobrainer'        if defined?(NoBrainer) && NoBrainer.class == Module
require 'patches/db/riak'             if defined?(Riak) && Riak.class == Module
require 'patches/db/neo4j'            if defined?(Neo4j::Core) && Neo4j::Core::Query.class == Class
