module Rack
  class MiniProfiler
    class MemoryStore < AbstractStore

      # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
      class CacheCleanupThread < Thread
      end

      EXPIRES_IN_SECONDS = 60 * 60 * 24

      def initialize(args = nil)
        args ||= {}
        @expires_in_seconds = args[:expires_in] || EXPIRES_IN_SECONDS
        @timer_struct_lock = Mutex.new
        @timer_struct_cache = {}
        @user_view_lock = Mutex.new
        @user_view_cache = {}

        # TODO: fix it to use weak ref, trouble is may be broken in 1.9 so need to use the 'ref' gem
        me = self
        t = CacheCleanupThread.new do
          interval = 10
          cleanup_cache_cycle = 3600
          cycle_count = 1

          until Thread.current[:should_exit] do
            # We don't want to hit the filesystem every 10s to clean up the cache so we need to do a bit of
            # accounting to avoid sleeping that entire time.  We don't want to sleep for the entire period because
            # it means the thread will stay live in hot deployment scenarios, keeping a potentially large memory
            # graph from being garbage collected upon undeploy.
            if cycle_count * interval >= cleanup_cache_cycle
              cycle_count = 1
              me.cleanup_cache
            end

            sleep(interval)
            cycle_count += 1
          end
        end

        at_exit { t[:should_exit] = true }

        t
      end

      def save(page_struct)
        @timer_struct_lock.synchronize {
          @timer_struct_cache[page_struct['Id']] = page_struct
        }
      end

      def load(id)
        @timer_struct_lock.synchronize {
          @timer_struct_cache[id]
        }
      end

      def set_unviewed(user, id)
        @user_view_lock.synchronize {
          @user_view_cache[user] ||= []
          @user_view_cache[user] << id
        }
      end

      def set_viewed(user, id)
        @user_view_lock.synchronize {
          @user_view_cache[user] ||= []
          @user_view_cache[user].delete(id)
        }
      end

      def get_unviewed_ids(user)
        @user_view_lock.synchronize {
          @user_view_cache[user]
        }
      end

      def cleanup_cache
        expire_older_than = ((Time.now.to_f - @expires_in_seconds) * 1000).to_i
        @timer_struct_lock.synchronize {
          @timer_struct_cache.delete_if { |k, v| v['Started'] < expire_older_than }
        }
      end
    end
  end
end
