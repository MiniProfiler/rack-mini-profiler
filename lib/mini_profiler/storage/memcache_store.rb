module Rack
  class MiniProfiler
    class MemcacheStore < AbstractStore

      EXPIRE_SECONDS = 60*60*24
      MAX_RETRIES = 10

      def initialize(client = nil, prefix = "MPMemcacheStore")
        require 'dalli' unless defined? Dalli
        @prefix = prefix
        @client = client || Dalli::Client.new(['localhost:11211'])
      end

      def save(page_struct)
        @client.set("#{@prefix}#{page_struct['Id']}", Marshal::dump(page_struct), EXPIRE_SECONDS)
      end

      def load(id)
        raw = @client.get("#{@prefix}#{id}")
        if raw
          Marshal::load raw
        end
      end

      def set_unviewed(user, id)
        @client.add("#{@prefix}-#{user}-v", [], EXPIRE_SECONDS)
        MAX_RETRIES.times do
          break if @client.cas("#{@prefix}-#{user}-v", EXPIRE_SECONDS) do |ids|
            ids << id unless ids.include?(id)
            ids
          end
        end
      end

      def set_viewed(user, id)
        @client.add("#{@prefix}-#{user}-v", [], EXPIRE_SECONDS)
        MAX_RETRIES.times do
          break if @client.cas("#{@prefix}-#{user}-v", EXPIRE_SECONDS) do |ids|
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
