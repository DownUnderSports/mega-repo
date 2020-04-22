# encoding: utf-8
# frozen_string_literal: true

module ClearCacheItems
  extend ActiveSupport::Concern

  included do
    after_commit :delete_cache_keys, on: %i[ create ]
    after_commit :clear_cache_if_needed, on: %i[ update ]
  end

  module ClassMethods
    def delete_cache_keys(cache_match_str)
      cache_keys_to_delete = Rails.
        redis.
        keys("page_cache.*").
        filter do |k|
          k.to_s =~
            Regexp.new(
              ".*downundersports.com.*#{cache_match_str}",
              true
            )
        end

      Rails.redis.del *cache_keys_to_delete if cache_keys_to_delete.present?
    end
  end

  def delete_cache_keys
    self.class.delete_cache_keys cache_match_str
  end

  private
    def clear_cache_if_needed
      delete_cache_keys if should_clear_cache?
    end

    def cache_match_str
      dus_id.sub('-', '-?')
    end

    def cache_related_keys
      []
    end

    def should_clear_cache?
      cache_related_keys.any? {|k| previous_changes[k] }
    end
end
