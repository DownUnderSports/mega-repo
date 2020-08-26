# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

# ThankYouTicket::Terms description
class ThankYouTicket < ApplicationRecord
  class Terms < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :edited_by, class_name: 'User'

    # == Validations ==========================================================
    validates_presence_of :body

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.latest
      order(:id).last || new
    end

    def subbed_specials(year: current_year)
      body.gsub("%YEAR%", year || current_year)
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
