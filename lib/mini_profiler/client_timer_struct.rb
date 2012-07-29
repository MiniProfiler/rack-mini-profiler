require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # This class holds the client timings
    class ClientTimerStruct < TimerStruct

      def self.init_instrumentation
        "<script type=\"text/javascript\">mPt=function(){var t=[];return{t:t,probe:function(n){t.push({d:new Date(),n:n})}}}()</script>"
      end
      
      def self.instrument(name,orig)
        probe = "<script>mPt.probe('#{name}')</script>"
        wrapped = probe
        wrapped << orig 
        wrapped << probe 
        wrapped
      end


      def initialize(env={})
        super
      end

      def self.init_from_form_data(env, page_struct)
        timings = []
        clientTimes, clientPerf, baseTime = nil 
        form = env['rack.request.form_hash']

        clientPerf = form['clientPerformance'] if form 
        clientTimes = clientPerf['timing'] if clientPerf 

        baseTime = clientTimes['navigationStart'].to_i if clientTimes
        return unless clientTimes && baseTime 

        probes = form['clientProbes']
        translated = {}
        if probes && probes != "null"
          probes.each do |id, val|
            name = val["n"]
            translated[name] ||= {} 
            if translated[name][:start]
              translated[name][:finish] = val["d"]
            else 
              translated[name][:start] = val["d"]
            end
          end
        end

        translated.each do |name, data|
          h = {"Name" => name, "Start" => data[:start].to_i - baseTime}
          h["Duration"] = data[:finish].to_i - data[:start].to_i if data[:finish]
          timings.push(h)
        end

        clientTimes.keys.find_all{|k| k =~ /Start$/ }.each do |k|
          start = clientTimes[k].to_i - baseTime 
          finish = clientTimes[k.sub(/Start$/, "End")].to_i - baseTime
          duration = 0 
          duration = finish - start if finish > start 
          name = k.sub(/Start$/, "").split(/(?=[A-Z])/).map{|s| s.capitalize}.join(' ')
          timings.push({"Name" => name, "Start" => start, "Duration" => duration}) if start >= 0
        end

        clientTimes.keys.find_all{|k| !(k =~ /(End|Start)$/)}.each do |k|
          timings.push("Name" => k, "Start" => clientTimes[k].to_i - baseTime, "Duration" => -1)
        end

        rval = self.new
        rval['RedirectCount'] = env['rack.request.form_hash']['clientPerformance']['navigation']['redirectCount']
        rval['Timings'] = timings
        rval
      end
    end

  end
end
