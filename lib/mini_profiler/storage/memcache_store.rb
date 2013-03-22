module Rack
  class MiniProfiler
    class MemcacheStore < AbstractStore

      EXPIRES_IN = 60*60*24
      MAX_RETRIES = 10

      def initialize(args = nil)
        require 'dalli' unless defined? Dalli
        args ||= {}
        @prefix = args[:prefix] || "MPMemcacheStore"
        @client = args[:client] || Dalli::Client.new
        @expires_in = args[:expires_in] || EXPIRES_IN
      end

      def save(page_struct)
        @client.set("#{@prefix}#{page_struct['Id']}", Marshal::dump(page_struct), @expires_in)
      end

      def load(id)
        raw = @client.get("#{@prefix}#{id}")
        if raw
          Marshal::load raw
        end
      end

      def set_unviewed(user, id)
        @client.add("#{@prefix}-#{user}-v", [], @expires_in)
        MAX_RETRIES.times do
          break if @client.cas("#{@prefix}-#{user}-v", @expires_in) do |ids|
            ids << id unless ids.include?(id)
            ids
          end
        end
      end

      def set_viewed(user, id)
        @client.add("#{@prefix}-#{user}-v", [], @expires_in)
        MAX_RETRIES.times do
          break if @client.cas("#{@prefix}-#{user}-v", @expires_in) do |ids|
            ids.delete id
            ids
          end
        end
      end

      def get_unviewed_ids(user)
        @client.get("#{@prefix}-#{user}-v") || []
      end

    end
  end
end
