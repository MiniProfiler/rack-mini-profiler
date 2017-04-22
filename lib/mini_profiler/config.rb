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
      :flamegraph_sample_rate, :logger, :pre_authorize_cb, :skip_paths,
      :skip_schema_queries, :storage, :storage_failure, :storage_instance,
      :storage_options, :user_provider
    attr_accessor :skip_sql_param_names, :suppress_encoding, :max_sql_param_length

    # ui accessors
    attr_accessor :collapse_results, :max_traces_to_show, :position,
      :show_children, :show_controls, :show_trivial, :start_hidden,
      :toggle_shortcut, :html_container

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
          @skip_schema_queries    = false
          @storage                = MiniProfiler::MemoryStore
          @user_provider          = Proc.new{|env| Rack::Request.new(env).ip}
          @authorization_mode     = :allow_all
          @backtrace_threshold_ms = 0
          @flamegraph_sample_rate = 0.5
          @storage_failure = Proc.new do |exception|
            if @logger
              @logger.warn("MiniProfiler storage failure: #{exception.message}")
            end
          end
          @enabled = true
          @disable_env_dump = false
          @max_sql_param_length = 0 # disable sql parameter collection by default
          @skip_sql_param_names = /password/ # skips parameters with the name password by default

          # ui parameters
          @autorized          = true
          @collapse_results   = true
          @max_traces_to_show = 20
          @position           = 'left'  # Where it is displayed
          @show_children      = false
          @show_controls      = false
          @show_trivial       = false
          @start_hidden       = false
          @toggle_shortcut    = 'Alt+P'
          @html_container     = 'body'

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
