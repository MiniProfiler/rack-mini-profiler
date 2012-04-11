module Rack
  class MiniProfiler

    # MiniProfiles page, part of 
    class PageStruct
      def initialize(env)
        @attributes = {
          "Id" => MiniProfiler.generate_id,
          "Name" => env['PATH_INFO'],
          "Started" => (Time.now.to_f * 1000).to_i,
          "MachineName" => env['SERVER_NAME'],
          "Level" => 0,
          "User" => "unknown user",
          "HasUserViewed" => false,
          "ClientTimings" => ClientTimerStruct.new(env),
          "DurationMilliseconds" => 0,
          "HasTrivialTimings" => true,
          "HasAllTrivialTimigs" => false,
          "TrivialDurationThresholdMilliseconds" => 2,
          "Head" => nil,
          "DurationMillisecondsInSql" => 0,
          "HasSqlTimings" => true,
          "HasDuplicateSqlTimings" => false,
          "ExecutedReaders" => 0,
          "ExecutedScalars" => 0,
          "ExecutedNonQueries" => 0
        }
        name = "#{env['REQUEST_METHOD']} http://#{env['SERVER_NAME']}:#{env['SERVER_PORT']}#{env['SCRIPT_NAME']}#{env['PATH_INFO']}"
        @attributes['Root'] = RequestTimerStruct.createRoot(name, self)
      end

      def [](name)
        @attributes[name]
      end

      def []=(name, val)
        @attributes[name] = val
      end

      def to_json(*a)
        attribs = @attributes.merge( {
          "Started" => '/Date(%d)/' % @attributes['Started'], 
          "DurationMilliseconds" => @attributes['Root']['DurationMilliseconds']
          })
        
        ::JSON.generate(attribs, *a)
      end
    end
    
  end
end