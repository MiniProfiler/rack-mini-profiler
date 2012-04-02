# rack-mini-profiler

Middleware that displays speed badge for every html page.

## What does it do

MiniProfiler keeps you aware of your site's performance as you are developing it.
It does this by....

env['x-rack-mini_profiler'] is the profiler 
## Using mini-profiler in your app

Install/add to Gemfile

	gem 'rack-mini-profiler'

Add it to your middleware stack:

Using Builder:

	builder = Rack::Builder.new do
  	use Rack::MiniProfiler

  	map('/')    { run get }
  end

Using Sinatra:

	require 'rack-mini-profiler '
	class MyApp < Sinatra::Base
		use Rack::MiniProfiler
	end

