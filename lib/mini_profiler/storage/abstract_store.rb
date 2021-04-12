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

      # a list of tokens that are permitted to access profiler in explicit mode
      def allowed_tokens
        raise NotImplementedError.new("allowed_tokens is not implemented")
      end

      def should_take_snapshot?(period)
        raise NotImplementedError.new("should_take_snapshot? is not implemented")
      end

      def push_snapshot(page_struct, config)
        raise NotImplementedError.new("push_snapshot is not implemented")
      end

      def fetch_snapshots(batch_size: 200, &blk)
        raise NotImplementedError.new("fetch_snapshots is not implemented")
      end

      def snapshot_groups_overview
        groups = {}
        fetch_snapshots do |batch|
          batch.each do |snapshot|
            group_name = default_snapshot_grouping(snapshot)
            hash = groups[group_name] ||= {}
            hash[:snapshots_count] ||= 0
            hash[:snapshots_count] += 1
            if !hash[:worst_score] || hash[:worst_score] < snapshot.duration_ms
              groups[group_name][:worst_score] = snapshot.duration_ms
            end
            if !hash[:best_score] || hash[:best_score] > snapshot.duration_ms
              groups[group_name][:best_score] = snapshot.duration_ms
            end
          end
        end
        groups = groups.to_a
        groups.sort_by! { |name, hash| hash[:worst_score] }
        groups.reverse!
        groups.map! { |name, hash| hash.merge(name: name) }
        groups
      end

      def find_snapshots_group(group_name)
        data = []
        fetch_snapshots do |batch|
          batch.each do |snapshot|
            snapshot_group_name = default_snapshot_grouping(snapshot)
            if group_name == snapshot_group_name
              data << {
                id: snapshot[:id],
                duration: snapshot.duration_ms,
                sql_count: snapshot[:sql_count],
                timestamp: snapshot[:started_at],
                custom_fields: snapshot[:custom_fields]
              }
            end
          end
        end
        data.sort_by! { |s| s[:duration] }
        data.reverse!
        data
      end

      def load_snapshot(id)
        raise NotImplementedError.new("load_snapshot is not implemented")
      end

      private

      def default_snapshot_grouping(snapshot)
        group_name = rails_route_from_path(snapshot[:request_path], snapshot[:request_method])
        group_name ||= snapshot[:request_path]
        "#{snapshot[:request_method]} #{group_name}"
      end

      def rails_route_from_path(path, method)
        if defined?(Rails) && defined?(ActionController::RoutingError)
          hash = Rails.application.routes.recognize_path(path, method: method)
          if hash && hash[:controller] && hash[:action]
            "#{hash[:controller]}##{hash[:action]}"
          end
        end
      rescue ActionController::RoutingError
        nil
      end
    end
  end
end
