28-June-2012 - Sam  
 
  * Started change log
  * Corrected profiler so it properly captures POST requests (was supressing non 200s)
  * Amended Rack.MiniProfiler.config[:user_provider] to use ip addres for identity 
  * Fixed bug where unviewed missing ids never got cleared
  * Supress all '/assets/' in the rails tie (makes debugging easier)
  * record_sql was mega buggy
