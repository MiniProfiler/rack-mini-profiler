# Rakefile
require 'rubygems'
require 'bundler'
require 'bundler/gem_tasks'

Bundler.setup(:default, :test)

require 'rubocop/rake_task'

RuboCop::RakeTask.new

task :default => [:rubocop, :spec]

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

desc "builds a gem"
task :build => :update_asset_version do
  `gem build rack-mini-profiler.gemspec 1>&2`
end

desc "compile sass"
task :compile_sass => :copy_files do
  `sass lib/html/includes.scss > lib/html/includes.css`
end

desc "update asset version file"
task :update_asset_version => :compile_sass do
  require 'digest/md5'
  h = []
  Dir.glob('lib/html/*.{js,html,css,tmpl}').each do |f|
    h << Digest::MD5.hexdigest(::File.read(f))
  end
  File.open('lib/mini_profiler/asset_version.rb','w') do |f|
    f.write \
"module Rack
  class MiniProfiler
    ASSET_VERSION = '#{Digest::MD5.hexdigest(h.sort.join(''))}'.freeze
  end
end"
  end
end


desc "copy files from other parts of the tree"
task :copy_files do
  # TODO grab files from MiniProfiler/UI
end

