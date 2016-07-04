source 'http://rubygems.org'

gemspec

gem 'codecov', :require => false, :group => :test

if RUBY_VERSION < '2.0.0'
  gem 'json', '~>1.8'
end

if RUBY_VERSION < '2.2.2'
  gem 'rack', '1.6.4'
end

group :development do
  gem 'guard', :platforms => [:mri_22, :mri_23]
  gem 'guard-rspec', :platforms => [:mri_22, :mri_23]
end
