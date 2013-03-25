module Rack
  class MiniProfiler
    class MemoryStore < AbstractStore

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
        Thread.new do
          while true do
            me.cleanup_cache
            sleep(3600)
          end
        end
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
