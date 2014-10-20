module MiniProfiler
  module Patches
    class SavonPatches
      def self.patched?
        @patched
      end

      def self.patched=(val)
        @patched = val
      end

      def self.class_exists?(name)
        eval(name + ".class").to_s.eql?('Class')
      rescue NameError
        false
      end

      def self.module_exists?(name)
        eval(name + ".class").to_s.eql?('Module')
      rescue NameError
        false
      end
    end

    if SavonPatches.class_exists? "Savon::Operation"
      Savon::Operation.class_eval do
        def call(locals = {}, &block)
          builder = build(locals, &block)
          response = Savon.notify_observers(@name, builder, @globals, @locals)

          request = build_request(builder)

          start = Time.now
          response ||= call! request
          elapsed_time = ((Time.now - start).to_f * 1000).round(1)

          raise_expected_httpi_response! unless response.kind_of?(HTTPI::Response)

          current = ::Rack::MiniProfiler.current
          if current && current.measure
            record = ::Rack::MiniProfiler.record_web_service(@name, request, response, elapsed_time)
            response.instance_variable_set("@miniprofiler_webservice_id", record) if response
          end

          Savon::Response.new(response, @globals, @locals)
        end
      end
    end

  end
end
