# rack-mini-profiler

[![Code Climate](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler.png)](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler) [![Build Status](https://travis-ci.org/MiniProfiler/rack-mini-profiler.png)](https://travis-ci.org/MiniProfiler/rack-mini-profiler)

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

## rack-mini-profiler needs your help

We have decided to restructure our repository so there is a central UI repo and the various language implementation have their own.

The new home for rack-mini-profiler is https://github.com/MiniProfiler/rack-mini-profiler

**WE NEED HELP.**

- Setting up a build that reuses https://github.com/MiniProfiler/ui
- Migrating the internal data structures per spec at: https://github.com/MiniProfiler/ui
- Cleaning up the horrendous class structure that using string as keys and crazy non-objects https://github.com/SamSaffron/MiniProfiler/blob/master/Ruby/lib/mini_profiler/sql_timer_struct.rb#L36-L44
- Add travis-ci testing at least MRI 1.9.3, JRuby and MRI 2.0

If you feel like taking on any of this start an issue and update us on your progress.

## Installation

Install/add to Gemfile

```ruby
gem 'rack-mini-profiler'
```

NOTE: Be sure to require rack_mini_profiler below the `pg` and `mysql` gems in your Gemfile. rack_mini_profiler will identify these gems if they are loaded to insert instrumentation. If included too early no SQL will show up.

#### Rails

All you have to do is include the Gem and you're good to go in development. See notes below for use in production.

#### Rack Builder

```ruby
require 'rack-mini-profiler'
builder = Rack::Builder.new do
  use Rack::MiniProfiler

  map('/')    { run get }
end
```

#### Sinatra

```ruby
require 'rack-mini-profiler'
class MyApp < Sinatra::Base
  use Rack::MiniProfiler
end
```

## Using rack-mini-profiler in your app

rack-mini-profiler is designed with production profiling in mind. To enable that just run `Rack::MiniProfiler.authorize_request` once you know a request is allowed to profile.

```ruby
# A hook in your ApplicationController
def authorize
  if current_user.is_admin?
    Rack::MiniProfiler.authorize_request
  end
end
```

## Database profiling

Currently supports Mysql2, Postgres, and Mongoid3 (with fallback support to ActiveRecord)

## Storage

rack-mini-profiler stores it's results so they can be shared later and aren't lost at the end of the request.

There are 4 storage options: `MemoryStore`, `RedisStore`, `MemcacheStore`, and `FileStore`.

`FileStore` is the default in Rails environments and will write files to `tmp/miniprofiler/*`.  `MemoryStore` is the default otherwise.

To change the default you can create a file in `config/initializers/mini_profiler.rb`

```ruby
# set MemoryStore
Rack::MiniProfiler.config.storage = Rack::MiniProfiler::MemoryStore

# set RedisStore
if Rails.env.production?
  uri = URI.parse(ENV["REDIS_SERVER_URL"])
  Rack::MiniProfiler.config.storage_options = { :host => uri.host, :port => uri.port, :password => uri.password }
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisStore
end
```

MemoryStore stores results in a processes heap - something that does not work well in a multi process environment.
FileStore stores results in the file system - something that may not work well in a multi machine environment.
RedisStore/MemcacheStore work in multi process and multi machine environments (RedisStore only saves results for up to 24 hours so it won't continue to fill up Redis).

Additionally you may implement an AbstractStore for your own provider.

## User result segregation

MiniProfiler will attempt to keep all user results isolated, out-of-the-box the user provider uses the ip address:

```ruby
Rack::MiniProfiler.config.user_provider = Proc.new{|env| Rack::Request.new(env).ip}
```

You can override (something that is very important in a multi-machine production setup):

```ruby
Rack::MiniProfiler.config.user_provider = Proc.new{ |env| CurrentUser.get(env) }
```

The string this function returns should be unique for each user on the system (for anonymous you may need to fall back to ip address)

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
# Have Mini Profiler start in hidden mode - display with short cut (defaulted to 'Alt+P')
Rack::MiniProfiler.config.start_hidden = true
# Don't collect backtraces on SQL queries that take less than 5 ms to execute
# (necessary on Rubies earlier than 2.0)
Rack::MiniProfiler.config.backtrace_threshold_ms = 5
```


In a Rails app, this can be done conveniently in an initializer such as config/initializers/mini_profiler.rb.

## Rails 2.X support

To get MiniProfiler working with Rails 2.3.X you need to do the initialization manually as well as monkey patch away an incompatibility between activesupport and json_pure.

Add the following code to your environment.rb (or just in a specific environment such as development.rb) for initialization and configuration of MiniProfiler.

```ruby
# configure and initialize MiniProfiler
require 'rack-mini-profiler'
c = ::Rack::MiniProfiler.config
c.pre_authorize_cb = lambda { |env|
  Rails.env.development? || Rails.env.production?
}
tmp = Rails.root.to_s + "/tmp/miniprofiler"
FileUtils.mkdir_p(tmp) unless File.exists?(tmp)
c.storage_options = {:path => tmp}
c.storage = ::Rack::MiniProfiler::FileStore
config.middleware.use(::Rack::MiniProfiler)
::Rack::MiniProfiler.profile_method(ActionController::Base, :process) {|action| "Executing action: #{action}"}
::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{@virtual_path}"}

# monkey patch away an activesupport and json_pure incompatability
# http://pivotallabs.com/users/alex/blog/articles/1332-monkey-patch-of-the-day-activesupport-vs-json-pure-vs-ruby-1-8
if JSON.const_defined?(:Pure)
  class JSON::Pure::Generator::State
    include ActiveSupport::CoreExtensions::Hash::Except
  end
end
```

## Available Options

* pre_authorize_cb - A lambda callback you can set to determine whether or not mini_profiler should be visible on a given request. Default in a Rails environment is only on in development mode. If in a Rack app, the default is always on.
* position - Can either be 'right' or 'left'. Default is 'left'.
* skip_schema_queries - Whether or not you want to log the queries about the schema of your tables. Default is 'false', 'true' in rails development.
* auto_inject (default true) - when false the miniprofiler script is not injected in the page
* backtrace_filter - a regex you can use to filter out unwanted lines from the backtraces
* toggle_shortcut (default Alt+P) - a jquery.hotkeys.js-style keyboard shortcut, used to toggle the mini_profiler's visibility. See http://code.google.com/p/js-hotkeys/ for more info.
* start_hidden (default false) - Whether or not you want the mini_profiler to be visible when loading a page
* backtrace_threshold_ms (default zero) - Minimum SQL query elapsed time before a backtrace is recorded. Backtrace recording can take a couple of milliseconds on rubies earlier than 2.0, impacting performance for very small queries.

## Special query strings

If you include the query string `pp=help` at the end of your request you will see the various options available. You can use these options to extend or contract the amount of diagnostics rack-mini-profiler gathers.

