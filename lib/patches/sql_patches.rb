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

require 'patches/db/mysql2'         if SqlPatches.class_exists? "Mysql2::Client"
require 'patches/db/pg'             if SqlPatches.class_exists? "PG::Result"
require 'patches/db/moped'          if SqlPatches.class_exists?("Moped::Node")
require 'patches/db/plucky'         if SqlPatches.class_exists?("Plucky::Query")
require 'patches/db/rsolr'          if SqlPatches.class_exists?("RSolr::Connection") && RSolr::VERSION[0] != "0"
require 'patches/db/sequel'         if !SqlPatches.patched? && SqlPatches.class_exists?("Sequel::Database")
require 'patches/db/activerecord'   if !SqlPatches.patched? && SqlPatches.module_exists?("ActiveRecord")
