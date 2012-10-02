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
task :build => :update_asset_version do
  Dir.chdir("..") do 
    `gem build rack-mini-profiler.gemspec 1>&2 && mv *.gem Ruby/`
  end
end

desc "compile less"
task :compile_less => :copy_files do
  `lessc lib/html/includes.less > lib/html/includes.css`
end

desc "update asset version file" 
task :update_asset_version => :compile_less do 
  require 'digest/md5'
  h = []
  Dir.glob('lib/html/*.{js,html,css,tmpl}').each do |f|
    h << Digest::MD5.hexdigest(::File.read(f))
  end
  File.open('lib/mini_profiler/version.rb','w') do |f| 
    f.write "module Rack
  class MiniProfiler 
    VERSION = '#{Digest::MD5.hexdigest(h.sort.join(''))}'.freeze
  end
end" 
  end
end


desc "copy files from other parts of the tree"
task :copy_files do
	`rm -R -f lib/html && mkdir lib/html 1>&2`
  path = ('../../../StackExchange.Profiling/UI')
  `ln -s #{path}/includes.less lib/html/includes.less`
  `ln -s #{path}/includes.js lib/html/includes.js`
  `ln -s #{path}/includes.tmpl lib/html/includes.tmpl`
  `ln -s #{path}/jquery.1.7.1.js lib/html/jquery.1.7.1.js`
  `ln -s #{path}/jquery.tmpl.js lib/html/jquery.tmpl.js`
  `ln -s #{path}/list.css lib/html/list.css`
  `ln -s #{path}/list.js lib/html/list.js`
  `ln -s #{path}/list.tmpl lib/html/list.tmpl`
  `ln -s #{path}/include.partial.html lib/html/profile_handler.js`
  `ln -s #{path}/share.html lib/html/share.html`
end

