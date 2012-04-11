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

