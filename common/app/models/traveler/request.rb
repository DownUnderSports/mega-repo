# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

# Traveler::Request description
class Traveler < ApplicationRecord
  class Request < ApplicationRecord
    # == Constants ============================================================
    CATEGORIES =
      %w[ flight medical diet room arrival departure other ].
        each_with_object({}) {|cat, obj| obj[cat] = cat}.
        freeze

    # == Attributes ===========================================================
    enum category: self::CATEGORIES, _suffix: :request

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :traveler, inverse_of: :requests

    # == Validations ==========================================================
    validates :category, inclusion: { in: categories.keys }

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
