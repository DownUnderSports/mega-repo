# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/message'

class User < ApplicationRecord
  class Alert < Message
    # == Constants ============================================================
    CATEGORIES = %i[
      alt_dates
      final_payment
      flights
      meals
      medical
      misc
      packages
      phobias
      rooming
      roommate
      uniform
    ].freeze

    # == Attributes ===========================================================
    enum category: CATEGORIES.to_db_enum

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================
    validate :final_payment_format

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.default_category
      'history'
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    private
      def final_payment_format
        if(final_payment?)
          errors.add(:category, "Final Payment alert must be only a date in the format: 'YYYY-MM-DD'") unless message =~ /^\d{4}\-\d{2}-\d{2}$/
        end
        true
      end
  end
end
