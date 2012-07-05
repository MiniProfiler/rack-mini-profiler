# rack-mini-profiler

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

## Using mini-profiler in your app

Install/add to Gemfile

```ruby
gem 'rack-mini-profiler'
```
Using Rails:

All you have to do is include the Gem and you're good to go in development.

Using Builder:

```ruby
require 'rack-mini-profiler'
builder = Rack::Builder.new do
  use Rack::MiniProfiler

  map('/')    { run get }
end
```

Using Sinatra:

```ruby
require 'rack-mini-profiler'
class MyApp < Sinatra::Base
  use Rack::MiniProfiler
end
```

## Running the Specs

```
$ rake build
$ rake spec
```

Additionally you can also run `autotest` if you like.

## Configuration Options

You can set configuration options using the configuration accessor on Rack::MiniProfiler:

```
# Have Mini Profiler show up on the right
Rack::MiniProfiler.config.position = 'right'
```

In a Rails app, this can be done conveniently in an initializer such as config/initializers/mini_profiler.rb.

## Available Options

* pre_authorize_cb - A lambda callback you can set to determine whether or not mini_profiler should be visible on a given request. Default in a Rails environment is only on in development mode. If in a Rack app, the default is always on.
* post_authorize_cb - A lambda that is called after your request executed to ensure you really have access to the results. 
* position - Can either be 'right' or 'left'. Default is 'left'.
* skip_schema_queries - Whether or not you want to log the queries about the schema of your tables. Default is 'false', 'true' in rails development.



