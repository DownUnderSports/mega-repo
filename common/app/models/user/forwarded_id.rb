# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class ForwardedId < ApplicationRecord
    include ClearCacheItems

    # == Constants ============================================================

    # == Attributes ===========================================================
    self.primary_key = 'original_id'

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user,
      optional: true,
      foreign_key: :dus_id,
      primary_key: :dus_id

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.get_ids
      all.map do |f|
        [f.original_id.dus_id_format, (f.dus_id.presence || f.original_id).dus_id_format]
      end.to_h
    rescue
      {}
    end


    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    private
      def cache_match_str
        "(#{%w[ original_id dus_id ].map {|v| v.dus_id_format.sub('-', '-?') } .join('|')})"
      end

      def should_clear_cache?
        true
      end

  end
end
