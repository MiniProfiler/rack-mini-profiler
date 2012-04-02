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