# Rakefile
require 'rubygems'
require 'rake'
require 'rake/testtask'

task :default => [:'test:all']

namespace :test do
  ENV['TESTOPTS'] = '-v'

  desc "all tests"
  Rake::TestTask.new("all") do |t|
	  t.pattern = 'test/*_test.rb'
	  t.verbose = true
	  t.warning = true
  end
end

desc "builds a gem"
task :build => :copy_files do
	`gem build rack-mini-profiler.gemspec 1>&2`
end

desc "copy files from other parts of the tree"
task :copy_files do
	`rm -R -f lib/html && mkdir lib/html 1>&2`
	`cp -v ../StackExchange.Profiling/UI/*.* lib/html 1>&2`
	# extract relevant javascript
	File.open('lib/html/profile_handler.js', 'w') do |f|
		puts 'extracting profile_handler.js from MiniProfilerHandler.cs'
		text = IO.read('lib/html/MiniProfilerHandler.cs')
		m = text.match /@"<script[^>]*>(.*)^<\/script>/m # find the big script
		script = m[1].gsub('""', '"')
		f.write('<script type="text/javascript">')
		f.write(script)
		f.write('</script>')
	end
end

