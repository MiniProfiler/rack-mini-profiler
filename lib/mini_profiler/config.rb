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

    attr_accessor :authorization_mode, :auto_inject, :backtrace_ignores,
      :backtrace_includes, :backtrace_remove, :backtrace_threshold_ms,
      :base_url_path, :disable_caching, :disable_env_dump, :enabled,
      :flamegraph_sample_rate, :logger, :position, :pre_authorize_cb,
      :skip_paths, :skip_schema_queries, :start_hidden, :storage,
      :storage_failure, :storage_instance, :storage_options, :toggle_shortcut,
      :user_provider, :collapse_results

    # Deprecated options
    attr_accessor :use_existing_jquery

      def self.default
        new.instance_eval {
          @auto_inject      = true # automatically inject on every html page
          @base_url_path    = "/mini-profiler-resources/"
          @disable_caching  = true
          # called prior to rack chain, to ensure we are allowed to profile
          @pre_authorize_cb = lambda {|env| true}

          # called after rack chain, to ensure we are REALLY allowed to profile
          @position               = 'left'  # Where it is displayed
          @skip_schema_queries    = false
          @storage                = MiniProfiler::MemoryStore
          @user_provider          = Proc.new{|env| Rack::Request.new(env).ip}
          @authorization_mode     = :allow_all
          @toggle_shortcut        = 'Alt+P'
          @start_hidden           = false
          @backtrace_threshold_ms = 0
          @flamegraph_sample_rate = 0.5
          @storage_failure = Proc.new do |exception|
            if @logger
              @logger.warn("MiniProfiler storage failure: #{exception.message}")
            end
          end
          @enabled = true
          @disable_env_dump = false
          @collapse_results = true
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
