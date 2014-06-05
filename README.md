# rack-mini-profiler

[![Code Climate](https://img.shields.io/codeclimate/github/MiniProfiler/rack-mini-profiler.svg)](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler) [![Build Status](https://img.shields.io/travis/MiniProfiler/rack-mini-profiler/master.svg)](https://travis-ci.org/MiniProfiler/rack-mini-profiler)

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

#### Features

* database profiling. Currently supports Mysql2, Postgres, and Mongoid3 (with fallback support to ActiveRecord)

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
- Cleaning up the [horrendous class structure that is using strings as keys and crazy non-objects](https://github.com/MiniProfiler/rack-mini-profiler/blob/master/lib/mini_profiler/sql_timer_struct.rb#L36-L44)

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

### Flamegraphs

To generate [flamegraphs](http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler):

* add the **flamegraph** gem to your Gemfile
* visit a page in your app with `?pp=flamegraph`

Flamegraph generation is supported in MRI 2.0 and 2.1 only.


## Access control in production

rack-mini-profiler is designed with production profiling in mind. To enable that just run `Rack::MiniProfiler.authorize_request` once you know a request is allowed to profile.

```ruby
# A hook in your ApplicationController
def authorize
  if current_user.is_admin?
    Rack::MiniProfiler.authorize_request
  end
end
```

## Configuration

Various aspects of rack-mini-profiler's behavior can be configured when your app boots.
For example in a Rails app, this should be done in an initializer:
**config/initializers/mini_profiler.rb**

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

MemoryStore stores results in a processes heap - something that does not work well in a multi process environment.
FileStore stores results in the file system - something that may not work well in a multi machine environment.
RedisStore/MemcacheStore work in multi process and multi machine environments (RedisStore only saves results for up to 24 hours so it won't continue to fill up Redis).

Additionally you may implement an AbstractStore for your own provider.

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

### Configuration Options

You can set configuration options using the configuration accessor on `Rack::MiniProfiler`.
For example:

```ruby
Rack::MiniProfiler.config.position = 'right'
Rack::MiniProfiler.config.start_hidden = true
```
The available configuration options are:

* pre_authorize_cb - A lambda callback you can set to determine whether or not mini_profiler should be visible on a given request. Default in a Rails environment is only on in development mode. If in a Rack app, the default is always on.
* position - Can either be 'right' or 'left'. Default is 'left'.
* skip_schema_queries - Whether or not you want to log the queries about the schema of your tables. Default is 'false', 'true' in rails development.
* auto_inject (default true) - when false the miniprofiler script is not injected in the page
* backtrace_filter - a regex you can use to filter out unwanted lines from the backtraces
* toggle_shortcut (default Alt+P) - a jquery.hotkeys.js-style keyboard shortcut, used to toggle the mini_profiler's visibility. See http://code.google.com/p/js-hotkeys/ for more info.
* start_hidden (default false) - Whether or not you want the mini_profiler to be visible when loading a page
* backtrace_threshold_ms (default zero) - Minimum SQL query elapsed time before a backtrace is recorded. Backtrace recording can take a couple of milliseconds on rubies earlier than 2.0, impacting performance for very small queries.
* flamegraph_sample_rate (default 0.5ms) - How often fast_stack should get stack trace info to generate flamegraphs

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
