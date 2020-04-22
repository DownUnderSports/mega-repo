# encoding: utf-8
# frozen_string_literal: true

require_dependency 'sport'

class Sport < ApplicationRecord
  class Info < ApplicationRecord
    include ClearCacheItems

    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :sport, touch: true

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def departing_dates_only
      self.departing_dates.to_s.gsub(/[A-Z][a-z]+day\,\s+/, '')
    end

    def returning_dates_only
      self.returning_dates.to_s.gsub(/[A-Z][a-z]+day\,\s+/, '')
    end

    private
      def cache_match_str
        sport.__send__ :cache_match_str
      end

      def should_clear_cache?
        true
      end
  end
end
