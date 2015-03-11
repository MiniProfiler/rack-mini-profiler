module Rack
  class MiniProfiler
    class ClientSettings

      COOKIE_NAME = "__profilin"

      BACKTRACE_DEFAULT = nil
      BACKTRACE_FULL    = 1
      BACKTRACE_NONE    = 2

      attr_accessor :disable_profiling
      attr_accessor :backtrace_level


      def initialize(env)
        request = ::Rack::Request.new(env)
        @cookie = request.cookies[COOKIE_NAME]
        if @cookie
          @cookie.split(",").map{|pair| pair.split("=")}.each do |k,v|
            @orig_disable_profiling = @disable_profiling = (v=='t') if k == "dp"
            @backtrace_level = v.to_i if k == "bt"
          end
        end

        @backtrace_level = nil if !@backtrace_level.nil? && (@backtrace_level == 0 || @backtrace_level > BACKTRACE_NONE)
        @orig_backtrace_level = @backtrace_level

      end

      def write!(headers)
        if @orig_disable_profiling != @disable_profiling || @orig_backtrace_level != @backtrace_level || @cookie.nil?
          settings = {"p" =>  "t" }
          settings["dp"] = "t"              if @disable_profiling
          settings["bt"] = @backtrace_level if @backtrace_level
          settings_string = settings.map{|k,v| "#{k}=#{v}"}.join(",")
          Rack::Utils.set_cookie_header!(headers, COOKIE_NAME, :value => settings_string, :path => '/')
        end
      end

      def discard_cookie!(headers)
        Rack::Utils.delete_cookie_header!(headers, COOKIE_NAME, :path => '/')
      end

      def has_cookie?
        !@cookie.nil?
      end

      def disable_profiling?
        @disable_profiling
      end

      def backtrace_full?
        @backtrace_level == BACKTRACE_FULL
      end

      def backtrace_default?
        @backtrace_level == BACKTRACE_DEFAULT
      end

      def backtrace_none?
        @backtrace_level == BACKTRACE_NONE
      end
    end
  end
end
