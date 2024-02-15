module Rack
  class MiniProfiler
    class QuerySettings
      def initialize(query_string, profile_parameter, skip_paths, path)
        @query_string = query_string
        @query_params = Rack::Utils.parse_nested_query(query_string)

        @profile_parameter = profile_parameter
        @skip_paths = skip_paths

        @path = path
      end

      def skip?
        @query_string.match?(/#{@profile_parameter}=skip/)
      end

      def skip_path?
        @skip_paths && @skip_paths.any? do |p|
          if p.instance_of?(String)
            @path.start_with?(p)
          elsif p.instance_of?(Regexp)
            p.match?(@path)
          end
        end
      end

      def profile_value
        @query_params[@profile_parameter]
      end

      def manual_enable?
        profile_value == 'enable'
      end

      def manual_disable?
        profile_value == 'disable'
      end

      def normal_backtrace?
        profile_value == 'normal-backtrace'
      end

      def no_backtrace?
        profile_value == 'no-backtrace'
      end

      def full_backtrace?
        profile_value == 'full-backtrace'
      end

      def trace_exceptions?
        profile_value == 'trace-exceptions'
      end

      # FIXME this should use profile_parameter and be the same as flamegraph?
      def pp_flamegraph?
        @query_string.match?(/pp=(async-)?flamegraph/)
      end

      def flamegraph_sample_rate
        match_data = @query_string.match(/flamegraph_sample_rate=([\d\.]+)/)
        if match_data && !match_data[1].to_f.zero?
          match_data[1].to_f
        end
      end

      VALID_MODES = [:cpu, :wall, :object, :custom].freeze
      def flamegraph_mode
        mode_match_data = @query_string.match(/flamegraph_mode=([a-zA-Z]+)/)

        if mode_match_data && VALID_MODES.include?(mode_match_data[1].to_sym)
          mode_match_data[1].to_sym
        end
      end

      def trace_exceptions_filter
        @query_params['trace_exceptions_filter']
      end

      def env?
        profile_value == 'env'
      end

      def analyze_memory?
        profile_value == 'analyze-memory'
      end

      def help?
        profile_value == 'help'
      end

      def flamegraph?
        profile_value == 'flamegraph'
      end

      def profile_gc?
        profile_value == 'profile-gc'
      end

      def profile_memory?
        profile_value == 'profile-memory'
      end

      def memory_profiler_options
        options = {
          ignore_files: @query_params['memory_profiler_ignore_files'],
          allow_files: @query_params['memory_profiler_allow_files'],
        }

        options[:top] = Integer(@query_params['memory_profiler_top']) if @query_params.key?('memory_profiler_top')

        options
      end
    end
  end
end
