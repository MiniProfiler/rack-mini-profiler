# CHANGELOG

## 

## 0.9.9.2 2016-03-06

- [FEATURE] on pageTransition collapse previously expanded timings

## 0.9.9.1 2016-03-06

- [FEATURE] expost MiniProfiler.pageTransition() for use by SPA web apps (@sam)

## 0.9.9 2016-03-06

- [FIX] removes alias_method_chain in favor of alias_method until Ruby 1.9.3 (@ayfredlund)
- [FIX] Dont block mongo when already patched for another db (@rrooding @kbrock)
- [FIX] get_profile_script when running under passenger configured with RailsBaseURI (@nspring)
- [FEATURE] Add support for neo4j (@ProGM)
- [FIX] ArgumentError: comparison of String with 200 failed (@paweljw)
- [FEATURE] Add support for Riak (@janx)
- [PERF] GC profiler much faster (@dgynn)
- [FIX] If local storage is disabled don't bomb out (@elia)
- [FIX] Create tmp directory when actually using it (@kbrock)
- [ADDED] Default collapse_results setting that collapses multiple timings on same page to a single one (@sam)
- [ADDED] Rack::MiniProfiler.profile_singleton_method (@kbrock)
- [CHANGE] Added Rack 2.0 support (and dropped support for Rack 1.1) (@dgynn)

## 0.9.8 - 2015-11-27 (Sam Saffron)

- [FEATURE] disable_env_dump config setting (@mathias)
- [FEATURE] set X-MiniProfiler-Ids for all 2XX reqs (@tymagu2)
- [FEATURE] add support for NoBrainer (rethinkdb) profiling (@niv)
- [FEATURE] add oracle enhanced adapter profiling (@rrooding)
- [FEATURE] pp=profile-memory can now parse query params (@dgynn)


## 0.9.7 - 2015-08-03 (Sam Saffron)

- [FEATURE] remove confusing pp=profile-gc-time (Nate Berkopec)
- [FEATURE] truncate strings in pp=analyze-memory (Nate Berkopec)
- [FEATURE] rename pp=profile-gc-ruby-head to pp=profile-memory (Nate Berkopec)

## 0.9.6 - 2015-07-08 (Sam Saffron)

- [FIX] incorrect truncation in pp=analyze-memory

## 0.9.5 - 2015-07-08 (Sam Saffron)

- [FEATURE] improve pp=analyze-memory

## 0.9.4 - 2015-07-08 (Sam Saffron)
- [UX] added a link to "more" actions in profiler
- [FEATURE] pp=help now displays links
- [FEATURE] simple memory report with pp=analyze-memory

## 0.9.2 - 2014-06-26 (Sam Saffron)
- [CHANGE] staging and other environments behave like production (Cedric Felizard)
- [DOC] CHANGELOG reorg (Olivier Lacan)
- [FIXED] Double calls to Rack::MiniProfilerRails.initialize! now raise an exception (Julik Tarkhanov)
- [FIXED] Add no-store header (George Mendoza)

## 0.9.1 - 2014-03-13 (Sam Saffron)
- [ADDED] Added back Ruby 1.8 support (thanks Malet)
- [IMPROVED] Amended Railstie so MiniProfiler can be launched with action view or action controller (Thanks Akira)
- [FIXED] Rails 3.0 support (thanks Zlatko)
- [FIXED] Possible XSS (admin only)
- [FIXED] Corrected Sql patching to avoid setting instance vars on nil which is frozen (thanks Andy, huoxito)

## 0.9.0.pre - 2013-12-12 (Sam Saffron)
- Bumped up version to reflect the stability of the project
- [IMPROVED] Reports for pp=profile-gc
- [IMPROVED] pp=flamegraph&flamegraph_sample_rate=1 , allow you to specify sampling rates

## 2013-09-17 (Ross Wilson)
- [IMPROVED] Instead of supressing all "/assets/" requests we now check the configured
  config.assets.prefix path since developers can rename the path to serve Asset Pipeline
  files from

## 2013-09-03
- [IMPROVED] Flamegraph now has much increased fidelity
- [REMOVED] Ripped out flamegraph so it can be isolated into a gem
- [REMOVED] Ripped out pp=sample it just was never really used

## 1.30 - 2013-08-30
- [ADDED] Rack::MiniProfiler.counter_method(klass,name) for injecting counters
- [FIXED] Counters were not shifting the table correctly

## 1.29 - 2013-08-20
- [ADDED] Implemented exception tracing using TracePoint see pp=trace-exceptions
- [FIXED] SOLR patching had an incorrect monkey patch

## 1.28 - 2012-07-18
- [FIXED] Diagnostics in abstract storage was raising not implemented killing
  ?pp=env and others
- [FIXED] SOLR xml unescaped by mistake

## 1.27 - 2013-06-26
- [ADDED] Rack::MiniProfiler.config.backtrace_threshold_ms
- [ADDED] jQuery 2.0 support
- [FIXED] Disabled global ajax handlers on MP requests @JP

## 1.26 - 2013-04-11
- [IMPROVED] Allow Rack::MiniProfilerRails.initialize!(Rails.application), for post config intialization

## 1.25 - 2013-04-08
- [FIXED] Missed flamegraph.html from build

## 1.24 - 2013-04-08
- [ADDED] Flame Graph Support see: http://samsaffron.com/archive/2013/03/19/flame-graphs-in-ruby-miniprofiler
- [ADDED] New toggle_shortcut and start_hidden options
- [ADDED] Mongoid support
- [ADDED] Rack::MiniProfiler.counter counter_name {}
- [ADDED] Net:HTTP profiling
- [ADDED] Ruby 1.8.7 support ... grrr
- [IMPROVED] More robust gc profiling
- [IMPROVED] Script tag initialized via data-attributes
- [IMPROVED] Allow usage of existing jQuery if its already loaded
- [IMPROVED] Pre-authorize to run in all non development? and production? modes
- [FIXED] AngularJS support and MooTools
- [FIXED] File retention leak in file_store
- [FIXED] HTML5 implicit <body> tags
- [FIXED] pp=enable

## 1.22 - 2012-09-20
- [FIXED] Permission issue in the gem

## 17-September-2012
- [IMPROVED] Allow rack-mini-profiler to be sourced from github
- [IMPROVED] Extracted the pp=profile-gc-time out, the object space profiler needs to disable gc

## 1.21 - 2012-09-17
- [ADDED] New MemchacedStore
- [ADDED] Rails 4 support

## 2012-09-12 (Sam Saffron)
- [ADDED] pp=profile-gc: allows you to profile the GC in Ruby 1.9.3

## 1.19 - 2012-09-10 (Sam Saffron)
- [FIXED] Compatibility issue with Ruby 1.8.7

## 1.17 - 2012-09-09 (Sam Saffron)
- [FIXED] pp=sample was bust unless stacktrace was installed

## 1.16 - 2012-09-05 (Sam Saffron)
- [IMPROVED] Implemented stacktrace properly
- [FIXED] Long standing problem specs (issue with memory store)
- [FIXED] Issue where profiler would be dumped when you got a 404 in production (and any time rails is bypassed)

## 1.15.pre - 2012-09-04 (Sam Saffron)
- [FIXED] Annoying bug where client settings were not sticking
- [FIXED] Long standing issue with Rack::ConditionalGet stopping MiniProfiler from working properly

## 1.13.pre - 2012-09-03 (Sam Saffron)
- [ADDED] Setting: config.backtrace_ignores = [] - an array of regexes that match on caller lines that get ignored
- [ADDED] Setting: config.backtrace_includes = [] - an array of regexes that get included in the trace by default
- [ADDED] pp=normal-backtrace to clear the "sticky" state
- [IMPROVED] Cleaned up the way client settings are stored
- [IMPROVED] Made pp=full-backtrace "sticky"
- [IMPROVED] Changed "pp=sample" to work with "caller" no need for stack trace gem
- [FIXED] pg gem prepared statements were not being logged correctly

## 1.12.pre - 2012-08-20 (Sam Saffron)
- [IMPROVED] Cap X-MiniProfiler-Ids at 10, otherwise the header can get killed

## 2012-08-10 (Sam Saffron)
- [ADDED] Basic prepared statement profiling for Postgres

## 2012-08-07 (Sam Saffron)
- [ADDED] Option to disable profiler for the current session (pp=disable / pp=enable)
- [ADDED] yajl compatability contributed by Sven Riedel

## 0.1.9 - 2012-07-30 (Sam Saffron)
- [IMPROVED] Made compliant with ancient versions of Rack (including Rack used by Rails2)
- [FIXED] Broken share link
- [FIXED] Crashes on startup (in MemoryStore and FileStore)
- [FIXED] Unicode issue

## 0.1.7 - 2012-07-18 (Sam Saffron)
- [ADDED] First Paint time for Google Chrome
- [FIXED] Ensure non Rails installs have mini profiler

## 2012-07-12 (Sam Saffron)
- [ADDED] Native PG and MySql2 interceptors, this gives way more accurate times
- [ADDED] some more client probing built in to rails
- [IMPROVED] Refactored context so its a proper class and not a hash
- [IMPROVED] More tests
- [FIXED] Incorrect profiling steps (was not indenting or measuring start time right

## 0.1.3 - 2012-07-09 (Sam Saffron)
- [ADDED] New option to display full backtraces pp=full-backtrace
- [IMPROVED] Cleaned up mechanism for profiling in production, all you need to do now
  is call Rack::MiniProfiler.authorize_request to get profiling working in
  production
- [IMPROVED] Cleaned up railties, got rid of the post authorize callback

## 2012-06-28 (Sam Saffron)
- [ADDED] Started change log
- [ADDED] added MemcacheStore
- [IMPROVED] Corrected profiler so it properly captures POST requests (was supressing non 200s)
- [IMPROVED] Amended Rack.MiniProfiler.config[:user_provider] to use ip addres for identity
- [IMPROVED] Supress all '/assets/' in the rails tie (makes debugging easier)
- [FIXED] Issue where unviewed missing ids never got cleared
- [FIXED] record_sql was mega buggy
