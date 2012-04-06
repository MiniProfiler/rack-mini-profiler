require 'ruby-debug'
Gem::Specification.new do |s|
	s.name = "rack-mini-profiler"
	s.version = "2.0.1a"
	s.summary = "Profiles loading speed for html pages."
	s.authors = ["Aleks Totic"]
	s.date = "2012-04-02"
	s.description = "Page loading speed displayed on every page. Optimize while you develop, peformance is a feature."
	s.email = "a@totic.org"
	s.homepage = "https://github.com/atotic/MiniProfiler"
	s.files = [
		'rack-mini-profiler.gemspec',
	].concat( Dir.glob('lib/**/*').reject {|f| File.directory? f } )
	s.extra_rdoc_files = [
		"README.md"
	]
	s.add_runtime_dependency 'rack', '>= 1.3' # for Rack::File.cache_control
	s.add_runtime_dependency 'ruby-debug', '>= 0.10' 
  if RUBY_VERSION < "1.9"
    s.add_runtime_dependency 'json', '>= 1.6' 
  end
end
