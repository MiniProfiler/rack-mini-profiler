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
        client_times, client_perf, base_time = nil
        form = env['rack.request.form_hash']

        client_perf = form[:client_performance] if form
        client_times = client_perf[:timing] if client_perf

        base_time = client_times[:navigation_start].to_i if client_times
        return unless client_times && base_time

        probes = form[:client_probes]
        translated = {}
        if probes && !["null", ""].include?(probes)
          probes.each do |id, val|
            name = val[:n]
            translated[name] ||= {}
            if translated[name][:start]
              translated[name][:finish] = val[:d]
            else
              translated[name][:start] = val[:d]
            end
          end
        end

        translated.each do |name, data|
          h = {:name => name, :start => data[:start].to_i - base_time}
          h[:duration] = data[:finish].to_i - data[:start].to_i if data[:finish]
          timings.push(h)
        end

        client_times.keys.find_all{|k| k =~ /_start$/ }.each do |k|
          start = client_times[k].to_i - base_time
          end_key = k.to_s.sub(/_start$/, "_end").to_sym
          finish = client_times[end_key].to_i - base_time
          duration = 0
          duration = finish - start if finish > start
          name = k.to_s.split("_").first.capitalize
          timings.push({:name => name, :start => start, :duration => duration}) if start >= 0
        end

        client_times.keys.find_all{|k| !(k =~ /(_end|_start)$/)}.each do |k|
          timings.push(:name => k, :start => client_times[k].to_i - base_time, :duration => -1)
        end

        rval = self.new
        rval[:redirect_count] = env['rack.request.form_hash'][:client_performance][:navigation][:redirect_count]
        rval[:timings] = timings
        rval
      end
    end

  end
end
