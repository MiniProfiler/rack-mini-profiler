require 'mini_profiler/timer_struct'

module Rack
  class MiniProfiler

    # This class holds the client timings
    class ClientTimerStruct < TimerStruct

      def initialize(env)
        super
      end

      def init_from_form_data(env, page_struct)
        timings = []
        clientTimes, clientPerf, baseTime = nil 
        form = env['rack.request.form_hash']

        clientPerf = form['clientPerformance'] if form 
        clientTimes = clientPerf['timing'] if clientPerf 

        baseTime = clientTimes['navigationStart'].to_i if clientTimes
        return unless clientTimes && baseTime 

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

        self['RedirectCount'] = env['rack.request.form_hash']['clientPerformance']['navigation']['redirectCount']
        self['Timings'] = timing
      end
    end

  end
end
