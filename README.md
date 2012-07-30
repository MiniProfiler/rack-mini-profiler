# rack-mini-profiler

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

## Using rack-mini-profiler in your app

Install/add to Gemfile

```ruby
gem 'rack-mini-profiler'
```
Using Rails:

All you have to do is include the Gem and you're good to go in development.

rack-mini-profiler is designed with production profiling in mind. To enable that just run `Rack::MiniProfiler.authorize_request` once you know a request is allowed to profile.

For example: 

```ruby
# A hook in your ApplicationController
def authorize
  if current_user.is_admin? 
    Rack::MiniProfiler.authorize_request
  end
end
````


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

## Storage

By default, rack-mini-profiler stores its results in a memory store: 

```ruby 
# our default
Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore
```

There are 2 other available storage engines, `RedisStore` and `FileStore`. 

MemoryStore is stores results in a processes heap - something that does not work well in a multi process environment. 
FileStore stores results in the file system - something that may not work well in a multi machine environment. 

Additionally you may implement an AbstractStore for your own provider. 

Rails hooks up a FileStore for all environments. 

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

## Rails 2.X support

MiniProfiler uses [railstie](https://github.com/SamSaffron/MiniProfiler/blob/master/Ruby/lib/mini_profiler_rails/railtie.rb) to bootstrap itself. This will not be called in a Rails 2 app. You are going to need to hook it up manually. (TODO: document this - pull request please)

## Available Options

* pre_authorize_cb - A lambda callback you can set to determine whether or not mini_profiler should be visible on a given request. Default in a Rails environment is only on in development mode. If in a Rack app, the default is always on.
* position - Can either be 'right' or 'left'. Default is 'left'.
* skip_schema_queries - Whether or not you want to log the queries about the schema of your tables. Default is 'false', 'true' in rails development.
* use_existing_jquery - Use the version of jQuery on the page as opposed to the self contained one
* auto_inject (default true) - when false the miniprofiler script is not injected in the page
* backtrace_filter - a regex you can use to filter out unwanted lines from the backtraces

## Special query strings 

If you include the query string `pp=help` at the end of your request you will see the various option you have. You can use these options to extend or contract the amount of diagnostics rack-mini-profiler gathers. 

