Gem::Specification.new do |s|
	s.name = "rack-mini-profiler"
	s.version = "0.1.3"
	s.summary = "Profiles loading speed for rack applications."
	s.authors = ["Aleks Totic","Sam Saffron", "Robin Ward"]
	s.date = "2012-04-02"
	s.description = "Page loading speed displayed on every page. Optimize while you develop, performance is a feature."
	s.email = "sam.saffron@gmail.com"
	s.homepage = "http://miniprofiler.com"
	s.files = [
		'rack-mini-profiler.gemspec',
	].concat( Dir.glob('lib/**/*').reject {|f| File.directory?(f) || f =~ /~$/ } )
	s.extra_rdoc_files = [
		"README.md",
    "CHANGELOG"
	]
	s.add_runtime_dependency 'rack', '>= 1.1.3' 
  if RUBY_VERSION < "1.9"
    s.add_runtime_dependency 'json', '>= 1.6' 
  end

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'activerecord', '~> 3.0'
end
