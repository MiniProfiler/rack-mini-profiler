# CHANGELOG
## 2012-06-28 (Sam Saffron)
- Started change log
- Corrected profiler so it properly captures POST requests (was supressing non 200s)
- Amended Rack.MiniProfiler.config[:user_provider] to use ip addres for identity
- Fixed bug where unviewed missing ids never got cleared
- Supress all '/assets/' in the rails tie (makes debugging easier)
- record_sql was mega buggy
- added MemcacheStore

## 0.1.3 - 2012-07-09 (Sam Saffron)
- Cleaned up mechanism for profiling in production, all you need to do now
  is call Rack::MiniProfiler.authorize_request to get profiling working in
  production
- Added option to display full backtraces pp=full-backtrace
- Cleaned up railties, got rid of the post authorize callback

## 2012-07-12 (Sam Saffron)
- Fixed incorrect profiling steps (was not indenting or measuring start time right
- Implemented native PG and MySql2 interceptors, this gives way more accurate times
- Refactored context so its a proper class and not a hash
- Added some more client probing built in to rails
- More tests

## 0.1.7 - 2012-07-18 (Sam Saffron)
- Added First Paint time for chrome
- Bug fix to ensure non Rails installs have mini profiler

## 0.1.9 - 2012-07-30 (Sam Saffron)
- Made compliant with ancient versions of Rack (including Rack used by Rails2)
- Fixed broken share link
- Fixed crashes on startup (in MemoryStore and FileStore)
- Unicode fix

## 2012-08-07 (Sam Saffron)
- Added option to disable profiler for the current session (pp=disable / pp=enable)
- yajl compatability contributed by Sven Riedel

## 2012-08-10 (Sam Saffron)
- Added basic prepared statement profiling for postgres

## 1.12.pre - 2012-08-20 (Sam Saffron)
- Cap X-MiniProfiler-Ids at 10, otherwise the header can get killed

## 1.13.pre - 2012-09-03 (Sam Saffron)
- pg gem prepared statements were not being logged correctly
- added setting config.backtrace_ignores = [] - an array of regexes that match on caller lines that get ignored
- added setting config.backtrace_includes = [] - an array of regexes that get included in the trace by default
- cleaned up the way client settings are stored
- made pp=full-backtrace "sticky"
- added pp=normal-backtrace to clear the "sticky" state
- change "pp=sample" to work with "caller" no need for stack trace gem

## 1.15.pre - 2012-09-04 (Sam Saffron)
- fixed annoying bug where client settings were not sticking
- fixed long standing issue with Rack::ConditionalGet stopping MiniProfiler from working properly

## 1.16 - 2012-09-05 (Sam Saffron)
- fixed long standing problem specs (issue with memory store)
- fixed issue where profiler would be dumped when you got a 404 in production (and any time rails is bypassed)
- implemented stacktrace properly

## 1.17 - 2012-09-09 (Sam Saffron)
- pp=sample was bust unless stacktrace was installed

## 1.19 - 2012-09-10 (Sam Saffron)
- fix compat issue with Ruby 1.8.7

## 2012-09-12 (Sam Saffron)
- Added pp=profile-gc , it allows you to profile the GC in Ruby 1.9.3

## 1.21 - 2012-09-17
- New MemchacedStore
- Rails 4 support

## 17-September-2012
- Allow rack-mini-profiler to be sourced from github
- Extracted the pp=profile-gc-time out, the object space profiler needs to disable gc

## 1.22 - 2012-09-20
- Fix permission issue in the gem

## 1.24 - 2013-04-08
- Flame Graph Support see: http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler
- Fix file retention leak in file_store
- New toggle_shortcut and start_hidden options
- Fix for AngularJS support and MooTools
- More robust gc profiling
- Mongoid support
- Fix for html5 implicit body tags
- script tag initialized via data-attributes
- new - Rack::MiniProfiler.counter counter_name {}
- Allow usage of existing jQuery if its already loaded
- Fix pp=enable
- Ruby 1.8.7 support ... grrr
- Net:HTTP profiling
- pre authorize to run in all non development? and production? modes

## 1.25 - 2013-04-08
- Missed flamegraph.html from build

## 1.26 - 2013-04-11
- (minor) allow Rack::MiniProfilerRails.initialize!(Rails.application), for post config intialization

## 1.27 - 2013-06-26
- Disable global ajax handlers on MP requests @JP
- Add Rack::MiniProfiler.config.backtrace_threshold_ms
- jQuery 2.0 support

## 1.28 - 2012-07-18
- diagnostics in abstract storage was raising not implemented killing
  ?pp=env and others
- SOLR xml unescaped by mistake

## 1.29 - 2013-08-20
- Bugfix: SOLR patching had an incorrect monkey patch
- Implemented exception tracing using TracePoint see pp=trace-exceptions

## 1.30 - 2013-08-30
- Feature: Added Rack::MiniProfiler.counter_method(klass,name) for injecting counters
- Bug: Counters were not shifting the table correctly

## 2013-09-03
- Ripped out flamegraph so it can be isolated into a gem
- Flamegraph now has much increased fidelity
- Ripped out pp=sample it just was never really used

## 2013-09-17 (Ross Wilson)
- Instead of supressing all "/assets/" requests we now check the configured
  config.assets.prefix path since developers can rename the path to serve Asset Pipeline
  files from

## 0.9.0.pre - 2013-12-12 (Sam Saffron)
- Bumped up version to reflect the stability of the project
- Improved reports for pp=profile-gc
- pp=flamegraph&flamegraph_sample_rate=1 , allow you to specify sampling rates

## 0.9.1 - 2014-03-13 (Sam Saffron)
- Added back Ruby 1.8 support (thanks Malet)
- Corrected Rails 3.0 support (thanks Zlatko)
- Corrected fix possible XSS (admin only)
- Amend Railstie so MiniProfiler can be launched with action view or action controller (Thanks Akira)
- Corrected Sql patching to avoid setting instance vars on nil which is frozen (thanks Andy, huoxito)
