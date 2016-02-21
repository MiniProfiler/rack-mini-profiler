module Rack
  class MiniProfiler
    class FileStore < AbstractStore

      # Sub-class thread so we have a named thread (useful for debugging in Thread.list).
      class CacheCleanupThread < Thread
      end

      class FileCache
        def initialize(path, prefix)
          @path = path
          @prefix = prefix
        end

        def [](key)
          begin
            data = ::File.open(path(key),"rb") {|f| f.read}
            return Marshal.load data
          rescue => e
            return nil
          end
        end

        def []=(key,val)
          ::File.open(path(key), "wb+") {|f| f.write Marshal.dump(val)}
        end

        private
        if RUBY_PLATFORM =~ /mswin(?!ce)|mingw|cygwin|bccwin/
          def path(key)
            @path + "/" + @prefix  + "_" + key.gsub(/:/, '_')
          end
        else
          def path(key)
            @path + "/" + @prefix  + "_" + key
          end
        end
      end

      EXPIRES_IN_SECONDS = 60 * 60 * 24

      def initialize(args = nil)
        args ||= {}
        @path = args[:path]
        @expires_in_seconds = args[:expires_in] || EXPIRES_IN_SECONDS
        raise ArgumentError.new :path unless @path
        FileUtils.mkdir_p(@path) unless ::File.exists?(@path)

        @timer_struct_cache = FileCache.new(@path, "mp_timers")
        @timer_struct_lock  = Mutex.new
        @user_view_cache    = FileCache.new(@path, "mp_views")
        @user_view_lock     = Mutex.new

        me = self
        t = CacheCleanupThread.new do
          interval = 10
          cleanup_cache_cycle = 3600
          cycle_count = 1

          begin
            until Thread.current[:should_exit] do
              # TODO: a sane retry count before bailing

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
          rescue
            # don't crash the thread, we can clean up next time
          end
        end

        at_exit { t[:should_exit] = true }

        t
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
          current = @user_view_cache[user]
          current = [] unless Array === current
          current << id
          @user_view_cache[user] = current.uniq
        }
      end

      def set_viewed(user, id)
        @user_view_lock.synchronize {
          @user_view_cache[user] ||= []
          current = @user_view_cache[user]
          current = [] unless Array === current
          current.delete(id)
          @user_view_cache[user] = current.uniq
        }
      end

      def get_unviewed_ids(user)
        @user_view_lock.synchronize {
          @user_view_cache[user]
        }
      end

      def cleanup_cache
        files = Dir.entries(@path)
        @timer_struct_lock.synchronize {
          files.each do |f|
            f = @path + '/' + f
            ::File.delete f if ::File.basename(f) =~ /^mp_timers/ and (Time.now - ::File.mtime(f)) > @expires_in_seconds
          end
        }
        @user_view_lock.synchronize {
          files.each do |f|
            f = @path + '/' + f
            ::File.delete f if ::File.basename(f) =~ /^mp_views/ and (Time.now - ::File.mtime(f)) > @expires_in_seconds
          end
        }
      end

    end
  end
end
