module Rack
  class MiniProfiler
    class FileStore < AbstractStore

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
        def path(key)
          @path + "/" + @prefix  + "_" + key
        end
      end

      EXPIRE_TIMER_CACHE = 3600 * 24
     
      def initialize(args)
        @path = args[:path]
        raise ArgumentError.new :path unless @path
        @timer_struct_cache = FileCache.new(@path, "mp_timers")
        @timer_struct_lock = Mutex.new
        @user_view_cache = FileCache.new(@path, "mp_views")
        @user_view_lock = Mutex.new

        me = self
        Thread.new do
          while true do
            me.cleanup_cache if MiniProfiler.instance
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
      

      private 


      def cleanup_cache
        files = Dir.entries(@path)
        @timer_struct_lock.synchronize {
          files.each do |f|
            f = @path + '/' + f
            File.delete f if f =~ /^mp_timers/ and (Time.now - File.mtime(f)) > EXPIRE_TIMER_CACHE
          end
        }
        @user_view_lock.synchronize {
          files.each do |f|
            f = @path + '/' + f
            File.delete f if f =~ /^mp_views/ and (Time.now - File.mtime(f)) > EXPIRE_TIMER_CACHE
          end
        }
      end
    
    end
  end
end
