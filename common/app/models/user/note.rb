# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/message'

class User < ApplicationRecord
  class Note < Message
    # == Constants ============================================================
    CATEGORIES = %i[ note ].freeze
    REASONS = %i[ other ].freeze

    # == Attributes ===========================================================
    enum category: CATEGORIES.to_db_enum
    enum reason: REASONS.to_db_enum

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_validation :category

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.default_category(*)
      'note'
    end

    def self.default_reason(*)
      'other'
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def category
      self.category = 'note' unless attributes['category'].to_s == 'note'
      super
    end

    def category=(*args)
      super(:note)
    end

    def reason
      self.reason = 'other' unless attributes['reason'].to_s == 'other'
      super
    end

    def reason=(*args)
      super(:other)
    end
  end
end
