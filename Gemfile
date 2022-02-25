# frozen_string_literal: true

source 'http://rubygems.org'
ruby '>= 2.5.0'

gemspec

group :test do
  gem 'codecov', require: false
  gem 'stackprof', require: false
end

group :development do
  gem 'guard', platforms: [:mri_22, :mri_23]
  gem 'guard-rspec', platforms: [:mri_22, :mri_23]
  gem 'rubocop', '>=0.77.0', require: false
end
