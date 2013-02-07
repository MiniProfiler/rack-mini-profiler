module Rack
  class MiniProfiler
    class Config

    def self.attr_accessor(*vars)
      @attributes ||= []
      @attributes.concat vars
      super(*vars)
    end
    
    def self.attributes
      @attributes
    end

    attr_accessor :auto_inject, :base_url_path, :pre_authorize_cb, :position,
        :backtrace_remove, :backtrace_includes, :backtrace_ignores, :skip_schema_queries, 
        :storage, :user_provider, :storage_instance, :storage_options, :skip_paths, :authorization_mode

    # Deprecated options
    attr_accessor :use_existing_jquery

      def self.default
        new.instance_eval {
          @auto_inject = true # automatically inject on every html page
          @base_url_path = "/mini-profiler-resources/"
          
          # called prior to rack chain, to ensure we are allowed to profile
          @pre_authorize_cb = lambda {|env| true} 
                                                  
          # called after rack chain, to ensure we are REALLY allowed to profile
          @position = 'left'  # Where it is displayed
          @skip_schema_queries = false
          @storage = MiniProfiler::MemoryStore
          @user_provider = Proc.new{|env| Rack::Request.new(env).ip}
          @authorization_mode = :allow_all
          @toggle_shortcut = 'Alt+P'
          @start_hidden = false
          self
        }
      end

      def merge!(config)
        return unless config
        if Hash === config 
          config.each{|k,v| instance_variable_set "@#{k}",v}
        else 
          self.class.attributes.each{ |k|  
            v = config.send k
            instance_variable_set "@#{k}", v if v
          }
        end
      end

    end
  end
end
