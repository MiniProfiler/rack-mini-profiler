# Mongoid 3 patches
if SqlPatches.class_exists?("Moped::Node")
  class Moped::Node
    alias_method :process_without_profiling, :process
    def process(*args,&blk)
      current = ::Rack::MiniProfiler.current
      return process_without_profiling(*args,&blk) unless current && current.measure

      start = Time.now
      result = process_without_profiling(*args,&blk)
      elapsed_time = ((Time.now - start).to_f * 1000).round(1)
      ::Rack::MiniProfiler.record_sql(args[0].log_inspect, elapsed_time)

      result
    end
  end
end
