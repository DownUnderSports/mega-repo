require "sidekiq/api"

module Sidekiq
  class SortedSet
    include Enumerable

    attr_reader :name

    def initialize(name)
      @name = name
      @_size = size
    end

    def size
      Sidekiq.redis { |c| c.zcard(name) }
    end

    def scan(match, count = 100)
      return to_enum(:scan, match, count) unless block_given?

      match = "*#{match}*" unless match.include?("*")
      Sidekiq.redis do |conn|
        conn.zscan_each(name, match: match, count: count) do |entry, score|
          yield SortedEntry.new(self, score, entry)
        end
      end
    end

    def clear
      Sidekiq.redis do |conn|
        conn.del(name)
      end
    end
    alias_method :💣, :clear
  end
end
