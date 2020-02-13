# frozen_string_literal: true

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mini_profiler/version'

Gem::Specification.new do |s|
  s.name = "rack-mini-profiler"
  s.version = Rack::MiniProfiler::VERSION
  s.summary = "Profiles loading speed for rack applications."
  s.authors = ["Sam Saffron", "Robin Ward", "Aleks Totic"]
  s.description = "Profiling toolkit for Rack applications with Rails integration. Client Side profiling, DB profiling and Server profiling."
  s.email = "sam.saffron@gmail.com"
  s.homepage = "https://miniprofiler.com"
  s.license = "MIT"
  s.files = [
    'rack-mini-profiler.gemspec',
  ].concat(Dir.glob('lib/**/*').reject { |f| File.directory?(f) || f =~ /~$/ })
  s.extra_rdoc_files = [
    "README.md",
    "CHANGELOG.md"
  ]
  s.add_runtime_dependency 'rack', '>= 1.2.0'
  s.required_ruby_version = '>= 2.3.0'

  s.metadata = {
    'source_code_uri' => 'https://github.com/MiniProfiler/rack-mini-profiler',
    'changelog_uri' => 'https://github.com/MiniProfiler/rack-mini-profiler/blob/master/CHANGELOG.md'
  }

  s.add_development_dependency 'rake', '< 11'
  s.add_development_dependency 'rack-test'
  s.add_development_dependency 'activerecord', '~> 3.0'
  s.add_development_dependency 'dalli'
  s.add_development_dependency 'rspec', '~> 3.6.0'
  s.add_development_dependency 'redis'
  s.add_development_dependency 'sassc'
  s.add_development_dependency 'flamegraph'
  s.add_development_dependency 'rubocop'
  s.add_development_dependency 'mini_racer'
  s.add_development_dependency 'nokogiri'
  s.add_development_dependency 'rubocop-discourse'

  s.require_paths = ["lib"]
end
