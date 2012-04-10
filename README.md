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

- Stack Traces for SQL called (added but mental, needs to be filtered to something usable) 
- Decide if we hook up SQL at the driver level (eg mysql gem) or library level (eg active record) - my personal perference is to do driver level hooks (Sam)
- Add automatic instrumentation for Rails (Controller times, Action times, Partial times, Layout times)
- Grab / display the parameters of SQL executed for parameterized SQL 
- Beef up the documentation 
- Auto-wire-up rails middleware 
- Review our API and ensure it is trivial
- Refactor big file into an organised structure, clean up namespacing 
- Add tests 

