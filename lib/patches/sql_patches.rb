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
end

require 'patches/db/mysql2'
require 'patches/db/pg'
require 'patches/db/moped'
require 'patches/db/plucky'
require 'patches/db/rsolr'
require 'patches/db/sequel'
require 'patches/db/activerecord'
