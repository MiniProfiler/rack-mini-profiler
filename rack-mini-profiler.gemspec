lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mini_profiler/version'

Gem::Specification.new do |s|
  s.name = "rack-mini-profiler"
  s.version = Rack::MiniProfiler::VERSION
  s.summary = "Profiles loading speed for rack applications."
  s.authors = ["Sam Saffron","Robin Ward","Aleks Totic"]
  s.description = "Profiling toolkit for Rack applications with Rails integration. Client Side profiling, DB profiling and Server profiling."
  s.email = "sam.saffron@gmail.com"
  s.homepage = "http://miniprofiler.com"
  s.license = "MIT"
  s.files = [
    'rack-mini-profiler.gemspec',
  ].concat( Dir.glob('lib/**/*').reject {|f| File.directory?(f) || f =~ /~$/ } )
  s.extra_rdoc_files = [
    "README.md",
    "CHANGELOG.md"
  ]
  s.add_runtime_dependency 'rack', '>= 1.2.0'
  if RUBY_VERSION < "1.9"
    s.add_runtime_dependency 'json', '>= 1.6'
  end

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'activerecord', '~> 3.0'
  s.add_development_dependency 'dalli'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'ZenTest'
  s.add_development_dependency 'autotest'
  s.add_development_dependency 'redis'
  s.add_development_dependency 'therubyracer'
  s.add_development_dependency 'less'
  s.add_development_dependency 'flamegraph'

  s.require_paths = ["lib"]
end
