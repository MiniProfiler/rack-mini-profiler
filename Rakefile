# Rakefile
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)

task :default => [:spec]

require 'rspec/core'
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = FileList['spec/**/*_spec.rb']
end

desc "builds a gem"
task :build => :copy_files do
	`gem build rack-mini-profiler.gemspec 1>&2`
end

desc "copy files from other parts of the tree"
task :copy_files do
	`rm -R -f lib/html && mkdir lib/html 1>&2`
	`cp -v ../StackExchange.Profiling/UI/*.* lib/html 1>&2`
	# TODO this is html it should not be .js
  `mv lib/html/include.partial.html lib/html/profile_handler.js`
end

