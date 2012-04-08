# rack-mini-profiler

Middleware that displays speed badge for every html page.

## What does it do

MiniProfiler keeps you aware of your site's performance as you are developing it.
It does this by....

env['profiler.mini'] is the profiler 
## Using mini-profiler in your app

Install/add to Gemfile

	gem 'rack-mini-profiler'

Add it to your middleware stack:

Using Builder:

	require 'rack-mini-profiler'
	builder = Rack::Builder.new do
  	use Rack::MiniProfiler

  	map('/')    { run get }
  end

Using Sinatra:

	require 'rack-mini-profiler'
	class MyApp < Sinatra::Base
		use Rack::MiniProfiler
	end

## TODO: prior to release - pull requests welcome

1. Stack Traces for SQL called
2. Decide if we hook up SQL at the driver level (eg mysql gem) or library level (eg active record) - my personal perference is to do driver level hooks (Sam)
3. We need to add automatic instrumentation for Rails (Controller times, Action times, Partial times, Layout times)
4. We need to grab / display the parameters of SQL executed for parameterized SQL 
5. We need to beef up the documentation 
6. We need to auto-wire-up rails middleware 
7. We need to review our API and ensure it is trivial

