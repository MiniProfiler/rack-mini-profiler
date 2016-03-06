# rack-mini-profiler

[![Code Climate](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler/badges/gpa.svg)](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler) [![Build Status](https://travis-ci.org/MiniProfiler/rack-mini-profiler.svg)](https://travis-ci.org/MiniProfiler/rack-mini-profiler)

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

#### Features

* database profiling. Currently supports Mysql2, Postgres, Oracle (oracle_enhanced ~> 1.5.0) and Mongoid3 (with fallback support to ActiveRecord)

#### Learn more

* [Visit our community](http://community.miniprofiler.com)
* [Watch the RailsCast](http://railscasts.com/episodes/368-miniprofiler)
* [Read about Flame graphs in rack-mini-profiler](http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler)
* [Read the announcement posts from 2012](http://samsaffron.com/archive/2012/07/12/miniprofiler-ruby-edition)

## rack-mini-profiler needs your help

We have decided to restructure our repository so there is a central UI repo and the various language implementation have their own.

**WE NEED HELP.**

- Setting up a build that reuses https://github.com/MiniProfiler/ui
- Migrating the internal data structures [per the spec](https://github.com/MiniProfiler/ui)

If you feel like taking on any of this start an issue and update us on your progress.

## Installation

Install/add to Gemfile

```ruby
gem 'rack-mini-profiler'
```

NOTE: Be sure to require rack_mini_profiler below the `pg` and `mysql` gems in your Gemfile. rack_mini_profiler will identify these gems if they are loaded to insert instrumentation. If included too early no SQL will show up.

#### Rails

All you have to do is include the Gem and you're good to go in development. See notes below for use in production.

#### Rails and manual initialization

In case you need to make sure rack_mini_profiler initialized after all other gems.
Or you want to execute some code before rack_mini_profiler required.

```ruby
gem 'rack-mini-profiler', require: false
```
Note the `require: false` part - if omitted, it will cause the Railtie for the mini-profiler to
be loaded outright, and an attempt to re-initialize it manually will raise an exception.

Then put initialize code in file like `config/initializers/rack_profiler.rb`

```ruby
if Rails.env == 'development'
  require 'rack-mini-profiler'

  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)
end
```

#### Rack Builder

```ruby
require 'rack-mini-profiler'

home = lambda { |env|
  [200, {'Content-Type' => 'text/html'}, ["<html><body>hello!</body></html>"]]
}

builder = Rack::Builder.new do
  use Rack::MiniProfiler
  map('/') { run home }
end

run builder
```

#### Sinatra

```ruby
require 'rack-mini-profiler'
class MyApp < Sinatra::Base
  use Rack::MiniProfiler
end
```

### Flamegraphs

To generate [flamegraphs](http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler):

* add the [**flamegraph**](https://github.com/SamSaffron/flamegraph) gem to your Gemfile
* visit a page in your app with `?pp=flamegraph`

Flamegraph generation is supported in MRI 2.0, 2.1, and 2.2 only.


## Access control in non-development environments

rack-mini-profiler is designed with production profiling in mind. To enable that just run `Rack::MiniProfiler.authorize_request` once you know a request is allowed to profile.

```ruby
  # inside your ApplicationController

  before_action do
    if current_user && current_user.is_admin?
      Rack::MiniProfiler.authorize_request
    end
  end
```

## Configuration

Various aspects of rack-mini-profiler's behavior can be configured when your app boots.
For example in a Rails app, this should be done in an initializer:
**config/initializers/mini_profiler.rb**

### Caching behavior
To fix some nasty bugs with rack-mini-profiler showing the wrong data, the middleware
will remove headers relating to caching (Date & Etag on responses, If-Modified-Since & If-None-Match on requests).
This probably won't ever break your application, but it can cause some unexpected behavior. For
example, in a Rails app, calls to `stale?` will always return true.

To disable this behavior, use the following config setting:

```ruby
# Do not let rack-mini-profiler disable caching
Rack::MiniProfiler.config.disable_caching = false # defaults to true
```

### Storage

rack-mini-profiler stores its results so they can be shared later and aren't lost at the end of the request.

There are 4 storage options: `MemoryStore`, `RedisStore`, `MemcacheStore`, and `FileStore`.

`FileStore` is the default in Rails environments and will write files to `tmp/miniprofiler/*`.  `MemoryStore` is the default otherwise.

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

`MemoryStore` stores results in a processes heap - something that does not work well in a multi process environment.
`FileStore` stores results in the file system - something that may not work well in a multi machine environment.
`RedisStore`/`MemcacheStore` work in multi process and multi machine environments (`RedisStore` only saves results for up to 24 hours so it won't continue to fill up Redis).

Additionally you may implement an `AbstractStore` for your own provider.

### User result segregation

MiniProfiler will attempt to keep all user results isolated, out-of-the-box the user provider uses the ip address:

```ruby
Rack::MiniProfiler.config.user_provider = Proc.new{|env| Rack::Request.new(env).ip}
```

You can override (something that is very important in a multi-machine production setup):

```ruby
Rack::MiniProfiler.config.user_provider = Proc.new{ |env| CurrentUser.get(env) }
```

The string this function returns should be unique for each user on the system (for anonymous you may need to fall back to ip address)

### Profiling specific methods

You can increase the granularity of profiling by measuring the performance of specific methods. Add methods of interest to an initializer.

```ruby
Rails.application.config.to_prepare do
  ::Rack::MiniProfiler.profile_singleton_method(User, :non_admins) { |a| "executing all_non_admins" }
  ::Rack::MiniProfiler.profile_method(User, :favorite_post) { |a| "executing favorite_post" }
end
```

### Using in SPA applications

Single page applications built using Ember, Angular or other frameworks need some special care, as routes often change without a full page load.

On route transition always call:

```
window.MiniProfiler.pageTransition();
```

This method will remove profiling information that was related to previous page and clear aggregate statistics.

### Configuration Options

You can set configuration options using the configuration accessor on `Rack::MiniProfiler`.
For example:

```ruby
Rack::MiniProfiler.config.position = 'right'
Rack::MiniProfiler.config.start_hidden = true
```
The available configuration options are:

Option|Default|Description
-------|---|--------
pre_authorize_cb|Rails: dev only<br>Rack: always on|A lambda callback that returns true to make mini_profiler visible on a given request.
position|`'left'`|Display mini_profiler on `'right'` or `'left'`.
skip_paths|`[]`|Paths that skip profiling.
skip_schema_queries|Rails dev: `'true'`<br>Othwerwise: `'false'`|`'true'` to log schema queries.
auto_inject|`true`|`true` to inject the miniprofiler script in the page.
backtrace_ignores|`[]`|Regexes of lines to be removed from backtraces.
backtrace_includes|Rails: `[/^\/?(app|config|lib|test)/]`<br>Rack: `[]`|Regexes of lines to keep in backtraces.
backtrace_remove|rails: `Rails.root`<br>Rack: `nil`|A string or regex to remove part of each line in the backtrace.
toggle_shortcut|Alt+P|Keyboard shortcut to toggle the mini_profiler's visibility. See [jquery.hotkeys](https://github.com/jeresig/jquery.hotkeys).
start_hidden|`false`|`false` to make mini_profiler visible on page load.
backtrace_threshold_ms|`0`|Minimum SQL query elapsed time before a backtrace is recorded. Backtrace recording can take a couple of milliseconds on rubies earlier than 2.0, impacting performance for very small queries.
flamegraph_sample_rate|`0.5ms`|How often to capture stack traces for flamegraphs.
disable_env_dump|`false`|`true` disables `?pp=env`, which prevents sending ENV vars over HTTP.
base_url_path|`'/mini-profiler-resources/'`|Path for assets; added as a prefix when naming assets and sought when responding to requests.
collapse_results|`true`|If multiple timing results exist in a single page, collapse them till clicked.

### Custom middleware ordering (required if using `Rack::Deflate` with Rails)

If you are using `Rack::Deflate` with rails and rack-mini-profiler in its default configuration,
`Rack::MiniProfiler` will be injected (as always) at position 0 in the middleware stack. This
will result in it attempting to inject html into the already-compressed response body. To fix this,
the middleware ordering must be overriden.

To do this, first add `, require: false` to the gemfile entry for rack-mini-profiler.
This will prevent the railtie from running. Then, customize the initialization
in the initializer like so:

```ruby
require 'rack-mini-profiler'

Rack::MiniProfilerRails.initialize!(Rails.application)

Rails.application.middleware.delete(Rack::MiniProfiler)
Rails.application.middleware.insert_after(Rack::Deflater, Rack::MiniProfiler)
```

Deleting the middleware and then reinserting it is a bit inelegant, but
a sufficient and costless solution. It is possible that rack-mini-profiler might
support this scenario more directly if it is found that
there is significant need for this confriguration or that
the above recipe causes problems.


## Special query strings

If you include the query string `pp=help` at the end of your request you will see the various options available. You can use these options to extend or contract the amount of diagnostics rack-mini-profiler gathers.


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
::Rack::MiniProfiler.profile_method(ActionView::Template, :render) {|x,y| "Rendering: #{path_without_format_and_extension}"}

# monkey patch away an activesupport and json_pure incompatability
# http://pivotallabs.com/users/alex/blog/articles/1332-monkey-patch-of-the-day-activesupport-vs-json-pure-vs-ruby-1-8
if JSON.const_defined?(:Pure)
  class JSON::Pure::Generator::State
    include ActiveSupport::CoreExtensions::Hash::Except
  end
end
```

## Running the Specs

```
$ rake build
$ rake spec
```

Additionally you can also run `autotest` if you like.

## Licence

The MIT License (MIT)

Copyright (c) 2013 Sam Saffron

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
