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

require 'patches/db/mysql2'
require 'patches/db/pg'
require 'patches/db/moped'
require 'patches/db/plucky'
require 'patches/db/rsolr'
require 'patches/db/sequel'
require 'patches/db/activerecord'
