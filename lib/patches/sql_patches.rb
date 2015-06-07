class SqlPatches

  def self.patched?
    @patched
  end

  def self.patched=(val)
    @patched = val
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

require 'patches/db/mysql2'         if defined?(Mysql2::Client)
require 'patches/db/pg'             if defined?(PG::Result)
require 'patches/db/moped'          if defined?(Moped::Node)
require 'patches/db/plucky'         if defined?(Plucky::Query)
require 'patches/db/rsolr'          if defined?(RSolr::Connection) && RSolr::VERSION[0] != "0"
require 'patches/db/sequel'         if !SqlPatches.patched? && defined?(Sequel::Database)
require 'patches/db/activerecord'   if !SqlPatches.patched? && defined?(ActiveRecord)
