# rack-mini-profiler

[![Code Climate](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler/badges/gpa.svg)](https://codeclimate.com/github/MiniProfiler/rack-mini-profiler) [![Build Status](https://travis-ci.org/MiniProfiler/rack-mini-profiler.svg)](https://travis-ci.org/MiniProfiler/rack-mini-profiler)

Middleware that displays speed badge for every html page. Designed to work both in production and in development.

#### Features

* Database profiling - Currently supports Mysql2, Postgres, Oracle (oracle_enhanced ~> 1.5.0) and Mongoid3 (with fallback support to ActiveRecord)
* Call-stack profiling - Flame graphs showing time spent by gem
* Memory profiling - Per-request memory usage, GC stats, and global allocation metrics

#### Learn more

* [Visit our community](http://community.miniprofiler.com)
* [Watch the RailsCast](http://railscasts.com/episodes/368-miniprofiler)
* [Read about Flame graphs in rack-mini-profiler](http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler)
* [Read the announcement posts from 2012](http://samsaffron.com/archive/2012/07/12/miniprofiler-ruby-edition)

## rack-mini-profiler needs your help

We have decided to restructure our repository so there is a central UI repo and the various language implementations have their own.

**WE NEED HELP.**

- Help [triage issues](https://www.codetriage.com/miniprofiler/rack-mini-profiler) [![Open Source Helpers](https://www.codetriage.com/miniprofiler/rack-mini-profiler/badges/users.svg)](https://www.codetriage.com/miniprofiler/rack-mini-profiler)

If you feel like taking on any of this start an issue and update us on your progress.

## Installation

Install/add to Gemfile in Ruby 2.3+

```ruby
gem 'rack-mini-profiler'
```

NOTE: Be sure to require rack_mini_profiler below the `pg` and `mysql` gems in your Gemfile. rack_mini_profiler will identify these gems if they are loaded to insert instrumentation. If included too early no SQL will show up.

You can also include optional libraries to enable additional features.
```ruby
# For memory profiling
gem 'memory_profiler'

# For call-stack profiling flamegraphs
gem 'flamegraph'
gem 'stackprof'
```

#### Rails

All you have to do is to include the Gem and you're good to go in development. See notes below for use in production.

#### Upgrading to version 2.0.0

Prior to version 2.0.0, Mini Profiler patched various Rails methods to get the information it needed such as template rendering time. Starting from version 2.0.0, Mini Profiler doesn't patch any Rails methods by default and relies on `ActiveSupport::Notifications` to get the information it needs from Rails. If you want Mini Profiler to keep using its patches in version 2.0.0 and later, change the gem line in your `Gemfile` to the following:

If you want to manually require Mini Profiler:
```ruby
gem 'rack-mini-profiler', require: ['enable_rails_patches']
```

If you don't want to manually require Mini Profiler:
```ruby
gem 'rack-mini-profiler', require: ['enable_rails_patches', 'rack-mini-profiler']
```

#### Rails and manual initialization

In case you need to make sure rack_mini_profiler is initialized after all other gems, or you want to execute some code before rack_mini_profiler required:

```ruby
gem 'rack-mini-profiler', require: false
```
Note the `require: false` part - if omitted, it will cause the Railtie for the mini-profiler to
be loaded outright, and an attempt to re-initialize it manually will raise an exception.

Then run the generator which will set up rack-mini-profiler in development:

```bash
bundle exec rails g rack_profiler:install
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

#### Hanami
For working with hanami, you need to use rack integration. Also, you need to add `Hanami::View::Rendering::Partial#render` method for profile:

```ruby
# config.ru
require 'rack-mini-profiler'
Rack::MiniProfiler.profile_method(Hanami::View::Rendering::Partial, :render) { "Render partial #{@options[:partial]}" }

use Rack::MiniProfiler
```

#### Patching ActiveRecord

A typical web application spends a lot of time querying the database. rack_mini_profiler will detect the ORM that is available
and apply patches to properly collect query statistics.

To make this work, declare the orm's gem before declaring `rack-mini-profiler` in the `Gemfile`:

```ruby
gem 'pg'
gem 'mongoid'
gem 'rack-mini-profiler'

```

If you wish to override this behavior, the environment variable `RACK_MINI_PROFILER_PATCH` is available.

```bash
export RACK_MINI_PROFILER_PATCH="pg,mongoid"
# or
export RACK_MINI_PROFILER_PATCH="false"
# initializers/rack_profiler.rb: SqlPatches.patch %w(mongo)
```

### Flamegraphs

To generate [flamegraphs](http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler):

* add the [**flamegraph**](https://github.com/SamSaffron/flamegraph) gem to your Gemfile
* visit a page in your app with `?pp=flamegraph`

### Memory Profiling

Memory allocations can be measured (using the [memory_profiler](https://github.com/SamSaffron/memory_profiler) gem)
which will show allocations broken down by gem, file location, and class and will also highlight `String` allocations.

Add `?pp=profile-memory` to the URL of any request while Rack::MiniProfiler is enabled to generate the report.

Additional query parameters can be used to filter the results.

* `memory_profiler_allow_files` - filename pattern to include (default is all files)
* `memory_profiler_ignore_files` - filename pattern to exclude (default is no exclusions)
* `memory_profiler_top` - number of results per section (defaults to 50)

The allow/ignore patterns will be treated as regular expressions.

Example: `?pp=profile-memory&memory_profiler_allow_files=active_record|app`

There are two additional `pp` options that can be used to analyze memory which do not require the `memory_profiler` gem

* Use `?pp=profile-gc` to report on Garbage Collection statistics
* Use `?pp=analyze-memory` to report on ObjectSpace statistics

## Access control in non-development environments

rack-mini-profiler is designed with production profiling in mind. To enable that run `Rack::MiniProfiler.authorize_request` once you know a request is allowed to profile.

```ruby
  # inside your ApplicationController

  before_action do
    if current_user && current_user.is_admin?
      Rack::MiniProfiler.authorize_request
    end
  end
```

> If your production application is running on more than one server (or more than one dyno) you will need to configure rack mini profiler's storage to use Redis or Memcache. See [storage](#storage) for information on changing the storage backend.

Note:

Out-of-the-box we will initialize the `authorization_mode` to `:whitelist` in production. However, in some cases we may not be able to do it:

- If you are running in development or test we will not enable whitelist mode
- If you use `require: false` on rack_mini_profiler we are unlikely to be able to run the railtie
- If you are running outside of rails we will not run the railtie

In those cases use:

```ruby
Rack::MiniProfiler.config.authorization_mode = :whitelist
```

When deciding to fully profile a page mini profiler consults with the `authorization_mode`

By default in production we attempt to set the authorization mode to `:whitelist` meaning that end user will only be able to see requests where somewhere `Rack::MiniProfiler.authorize_request` is invoked.

In development we run in the `:allow_all` authorization mode meaning every request is profiled and displayed to the end user.


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
  Rack::MiniProfiler.config.storage_options = { url: ENV["REDIS_SERVER_URL"] }
  Rack::MiniProfiler.config.storage = Rack::MiniProfiler::RedisStore
end
```

`MemoryStore` stores results in a processes heap - something that does not work well in a multi process environment.
`FileStore` stores results in the file system - something that may not work well in a multi machine environment.
`RedisStore`/`MemcacheStore` work in multi process and multi machine environments (`RedisStore` only saves results for up to 24 hours so it won't continue to fill up Redis). You will need to add `gem redis`/`gem dalli` respectively to your `Gemfile` to use these stores.

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

### Profiling arbitrary block of code

It is also possible to profile any arbitrary block of code by passing a block to `Rack::MiniProfiler.step(name, opts=nil)`.

```ruby
Rack::MiniProfiler.step('Adding two elements') do
  result = 1 + 2
end
```

### Using in SPA applications

Single page applications built using Ember, Angular or other frameworks need some special care, as routes often change without a full page load.

On route transition always call:

```
window.MiniProfiler.pageTransition();
```

This method will remove profiling information that was related to previous page and clear aggregate statistics.

#### MiniProfiler's speed badge on pages that are not generated via Rails
You need to inject the following in your SPA to load MiniProfiler's speed badge ([extra details surrounding this script](https://github.com/MiniProfiler/rack-mini-profiler/issues/139#issuecomment-192880706)):

```html
 <script async type="text/javascript" id="mini-profiler" src="/mini-profiler-resources/includes.js?v=12b4b45a3c42e6e15503d7a03810ff33" data-version="12b4b45a3c42e6e15503d7a03810ff33" data-path="/mini-profiler-resources/" data-current-id="redo66j4g1077kto8uh3" data-ids="redo66j4g1077kto8uh3" data-horizontal-position="left" data-vertical-position="top" data-trivial="false" data-children="false" data-max-traces="10" data-controls="false" data-authorized="true" data-toggle-shortcut="Alt+P" data-start-hidden="false" data-collapse-results="true"></script>
```

_Note:_ The GUID (`data-version` and the `?v=` parameter on the `src`) will change with each release of `rack_mini_profiler`. The MiniProfiler's speed badge will continue to work, although you will have to change the GUID to expire the script to fetch the most recent version.

#### Using MiniProfiler's built in route for apps without HTML responses
MiniProfiler also ships with a `/rack-mini-profiler/requests` route that displays the speed badge on a blank HTML page. This can be useful when profiling an application that does not render HTML.

### Configuration Options

You can set configuration options using the configuration accessor on `Rack::MiniProfiler`.
For example:

```ruby
Rack::MiniProfiler.config.position = 'bottom-right'
Rack::MiniProfiler.config.start_hidden = true
```
The available configuration options are:

Option|Default|Description
-------|---|--------
pre_authorize_cb|Rails: dev only<br>Rack: always on|A lambda callback that returns true to make mini_profiler visible on a given request.
position|`'top-left'`|Display mini_profiler on `'top-right'`, `'top-left'`, `'bottom-right'` or `'bottom-left'`.
skip_paths|`[]`|Paths that skip profiling.
skip_schema_queries|Rails dev: `'true'`<br>Othwerwise: `'false'`|`'true'` to log schema queries.
auto_inject|`true`|`true` to inject the miniprofiler script in the page.
backtrace_ignores|`[]`|Regexes of lines to be removed from backtraces.
backtrace_includes|Rails: `[/^\/?(app\|config\|lib\|test)/]`<br>Rack: `[]`|Regexes of lines to keep in backtraces.
backtrace_remove|rails: `Rails.root`<br>Rack: `nil`|A string or regex to remove part of each line in the backtrace.
toggle_shortcut|Alt+P|Keyboard shortcut to toggle the mini_profiler's visibility. See [jquery.hotkeys](https://github.com/jeresig/jquery.hotkeys).
start_hidden|`false`|`false` to make mini_profiler visible on page load.
backtrace_threshold_ms|`0`|Minimum SQL query elapsed time before a backtrace is recorded.
flamegraph_sample_rate|`0.5`|How often to capture stack traces for flamegraphs in milliseconds.
base_url_path|`'/mini-profiler-resources/'`|Path for assets; added as a prefix when naming assets and sought when responding to requests.
collapse_results|`true`|If multiple timing results exist in a single page, collapse them till clicked.
max_traces_to_show|20|Maximum number of mini profiler timing blocks to show on one page
html_container|`body`|The HTML container (as a jQuery selector) to inject the mini_profiler UI into
show_total_sql_count|`false`|Displays the total number of SQL executions.
enable_advanced_debugging_tools|`false`|Enables sensitive debugging tools that can be used via the UI. In production we recommend keeping this disabled as memory and environment debugging tools can expose contents of memory that may contain passwords.

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
FileUtils.mkdir_p(tmp) unless File.exist?(tmp)
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
