class SqlPatches

  def self.patched?
    @patched
  end

  def self.patched=(val)
    @patched = val
  end

  def self.class_exists?(name)
    eval(name + ".class").to_s.eql?('Class')
  rescue NameError
    false
  end

  def self.correct_version?(required_version, klass)
    Gem::Dependency.new('', required_version).match?('', klass::VERSION)
  rescue NameError
    false
  end

  def self.module_exists?(name)
    eval(name + ".class").to_s.eql?('Module')
  rescue NameError
    false
  end

  def self.record_sql(statement, &block)
    start  = Time.now
    result = yield
    record = ::Rack::MiniProfiler.record_sql( statement, elapsed_time(start) )
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

require 'patches/db/mysql2'           if defined?(Mysql2::Client) && SqlPatches.class_exists?("Mysql2::Client")
require 'patches/db/pg'               if defined?(PG::Result) && SqlPatches.class_exists?("PG::Result")
require 'patches/db/oracle_enhanced'  if defined?(ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter) && SqlPatches.class_exists?("ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter") && SqlPatches.correct_version?('~> 1.5.0', ActiveRecord::ConnectionAdapters::OracleEnhancedAdapter)
require 'patches/db/mongo'            if defined?(Mongo) && SqlPatches.module_exists?("Mongo")
require 'patches/db/moped'            if defined?(Moped::Node) && SqlPatches.class_exists?("Moped::Node")
require 'patches/db/plucky'           if defined?(Plucky::Query) && SqlPatches.class_exists?("Plucky::Query")
require 'patches/db/rsolr'            if defined?(RSolr::Connection) && SqlPatches.class_exists?("RSolr::Connection") && RSolr::VERSION[0] != "0"
require 'patches/db/sequel'           if defined?(Sequel::Database) && !SqlPatches.patched? && SqlPatches.class_exists?("Sequel::Database")
require 'patches/db/activerecord'     if defined?(ActiveRecord) &&!SqlPatches.patched? && SqlPatches.module_exists?("ActiveRecord")
require 'patches/db/nobrainer'        if defined?(NoBrainer) && SqlPatches.module_exists?("NoBrainer")
require 'patches/db/riak'             if defined?(Riak) && SqlPatches.module_exists?("Riak")
require 'patches/db/neo4j'            if defined?(Neo4j::Core) && SqlPatches.class_exists?("Neo4j::Core::Query")
