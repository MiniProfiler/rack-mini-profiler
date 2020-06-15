# frozen_string_literal: true

module Rack
  class MiniProfiler
    class MemoryStore < AbstractStore

      # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
      class CacheCleanupThread < Thread

        def initialize(interval, cycle, store)
          super
          @store       = store
          @interval    = interval
          @cycle       = cycle
          @cycle_count = 1
        end

        def should_cleanup?
          @cycle_count * @interval >= @cycle
        end

        # We don't want to hit the filesystem every 10s to clean up the cache so we need to do a bit of
        # accounting to avoid sleeping that entire time.  We don't want to sleep for the entire period because
        # it means the thread will stay live in hot deployment scenarios, keeping a potentially large memory
        # graph from being garbage collected upon undeploy.
        def sleepy_run
          cleanup if should_cleanup?
          sleep(@interval)
          increment_cycle
        end

        def cleanup
          @store.cleanup_cache
          @cycle_count = 1
        end

        def cycle_count
          @cycle_count
        end

        def increment_cycle
          @cycle_count += 1
        end
      end

      EXPIRES_IN_SECONDS = 60 * 60 * 24
      CLEANUP_INTERVAL   = 10
      CLEANUP_CYCLE      = 3600

      def initialize(args = nil)
        args ||= {}
        @expires_in_seconds = args.fetch(:expires_in) { EXPIRES_IN_SECONDS }

        @token1, @token2, @cycle_at = nil

        initialize_locks
        initialize_cleanup_thread(args)
      end

      def initialize_locks
        @token_lock         = Mutex.new
        @timer_struct_lock  = Mutex.new
        @user_view_lock     = Mutex.new
        @timer_struct_cache = {}
        @user_view_cache    = {}
      end

      #FIXME: use weak ref, trouble it may be broken in 1.9 so need to use the 'ref' gem
      def initialize_cleanup_thread(args = {})
        cleanup_interval = args.fetch(:cleanup_interval) { CLEANUP_INTERVAL }
        cleanup_cycle    = args.fetch(:cleanup_cycle)    { CLEANUP_CYCLE }
        t = CacheCleanupThread.new(cleanup_interval, cleanup_cycle, self) do
          until Thread.current[:should_exit] do
            t.sleepy_run
          end
        end
        at_exit { t[:should_exit] = true }
      end

      def save(page_struct)
        @timer_struct_lock.synchronize {
          @timer_struct_cache[page_struct[:id]] = page_struct
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

      def set_all_unviewed(user, ids)
        @user_view_lock.synchronize {
          @user_view_cache[user] = ids
        }
      end

      def get_unviewed_ids(user)
        @user_view_lock.synchronize {
          @user_view_cache[user]
        }
      end

      def cleanup_cache
        expire_older_than = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - @expires_in_seconds) * 1000).to_i
        @timer_struct_lock.synchronize {
          @timer_struct_cache.delete_if { |k, v| v[:started] < expire_older_than }
        }
      end

      def allowed_tokens
        @token_lock.synchronize do

          unless @cycle_at && (@cycle_at > Process.clock_gettime(Process::CLOCK_MONOTONIC))
            @token2 = @token1
            @token1 = SecureRandom.hex
            @cycle_at = Process.clock_gettime(Process::CLOCK_MONOTONIC) + Rack::MiniProfiler::AbstractStore::MAX_TOKEN_AGE
          end

          [@token1, @token2].compact

        end
      end
    end
  end
end
