# frozen_string_literal: true

module Rack
  class MiniProfiler
    class AbstractStore

      # maximum age of allowed tokens before cycling in seconds
      MAX_TOKEN_AGE = 1800

      def save(page_struct)
        raise NotImplementedError.new("save is not implemented")
      end

      def load(id)
        raise NotImplementedError.new("load is not implemented")
      end

      def set_unviewed(user, id)
        raise NotImplementedError.new("set_unviewed is not implemented")
      end

      def set_viewed(user, id)
        raise NotImplementedError.new("set_viewed is not implemented")
      end

      def set_all_unviewed(user, ids)
        raise NotImplementedError.new("set_all_unviewed is not implemented")
      end

      def get_unviewed_ids(user)
        raise NotImplementedError.new("get_unviewed_ids is not implemented")
      end

      def diagnostics(user)
        # this is opt in, no need to explode if not implemented
        ""
      end

      # a list of tokens that are permitted to access profiler in whitelist mode
      def allowed_tokens
        raise NotImplementedError.new("allowed_tokens is not implemented")
      end

      def should_take_snapshot?(period)
        raise NotImplementedError.new("should_take_snapshot? is not implemented")
      end

      def push_snapshot(page_struct, group_name, config)
        raise NotImplementedError.new("push_snapshot is not implemented")
      end

      def snapshots_overview
        raise NotImplementedError.new("snapshots_overview is not implemented")
      end

      def group_snapshots_list(group_name)
        raise NotImplementedError.new("group_snapshots_list is not implemented")
      end

      def load_snapshot(id, group_name)
        raise NotImplementedError.new("load_snapshot is not implemented")
      end
    end
  end
end
