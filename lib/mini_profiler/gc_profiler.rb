class Rack::MiniProfiler::GCProfiler
  
  def object_space_stats
    stats = {}
    ids = Set.new
    i=0
    ObjectSpace.each_object { |o|
      i = stats[o.class] || 0
      i += 1
      stats[o.class] = i
      ids << o.object_id if Integer === o.object_id 
    }
    {:stats => stats, :ids => ids}
  end

  def diff_object_stats(before,after)
    diff = {}
    after.each do |k,v|
      diff[k] = v - (before[k] || 0)
    end
    before.each do |k,v|
      diff[k] = 0 - v unless after[k]
    end

    diff
  end

  def analyze_strings(ids_before,ids_after)
    result = {}
    ids_after.each do |id|
      obj = ObjectSpace._id2ref(id)
      if String === obj && !ids_before.include?(obj.object_id) 
        result[obj] ||= 0 
        result[obj] += 1
      end
    end
    result
  end

  def profile_gc_time(app,env)
    body = []

    begin
      GC::Profiler.clear
      GC::Profiler.enable
      b = app.call(env)[2]
      b.close if b.respond_to? :close
      body << "GC Profiler ran during this request, if it fired you will see the cost below:\n\n"
      body << GC::Profiler.result
    ensure
      GC.enable
      GC::Profiler.disable
    end

    return [200, {'Content-Type' => 'text/plain'}, body]
  end

  def profile_gc(app,env)
    
    body = [];

    stat_before,stat_after,diff,string_analysis = nil
    begin
      GC.disable
      stat_before = object_space_stats
      b = app.call(env)[2]
      b.close if b.respond_to? :close
      stat_after = object_space_stats
      
      diff = diff_object_stats(stat_before[:stats],stat_after[:stats])
      string_analysis = analyze_strings(stat_before[:ids], stat_after[:ids])
    ensure
      GC.enable
    end


    body << "
ObjectSpace delta caused by request:
--------------------------------------------\n"
    diff.to_a.reject{|k,v| v == 0}.sort{|x,y| y[1] <=> x[1]}.each do |k,v|
      body << "#{k} : #{v}\n" if v != 0
    end

    body << "\n
ObjectSpace stats:
-----------------\n"

    stat_after[:stats].to_a.sort{|x,y| y[1] <=> x[1]}.each do |k,v|
      body << "#{k} : #{v}\n" 
    end


    body << "\n
String stats:
------------\n"

    string_analysis.to_a.sort{|x,y| y[1] <=> x[1] }.take(1000).each do |string,count|
      body << "#{count} : #{string}\n"
    end

    return [200, {'Content-Type' => 'text/plain'}, body]
  end
end
