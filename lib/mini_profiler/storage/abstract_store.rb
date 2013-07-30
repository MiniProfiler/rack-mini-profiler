module Rack
  class MiniProfiler
    class AbstractStore

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

      def get_unviewed_ids(user)
        raise NotImplementedError.new("get_unviewed_ids is not implemented")
      end

      def diagnostics(user)
        # this is opt in, no need to explode if not implemented
        ""
      end

    end
  end
end
