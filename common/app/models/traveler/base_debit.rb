# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class BaseDebit < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "public.traveler_base_debits"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    has_many :debits, inverse_of: :base_debit

    # == Validations ==========================================================

    # == Scopes ===============================================================
    scope :defaults, -> { where(is_default: true) }

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.additional_sport
      find_by(name: 'Additional Sport')
    end

    def self.domestic
      find_by(name: [ 'Domestic Airfare', 'Additional Airfare' ])
    end

    def self.insurance
      find_by(name: 'Travelex Insurance')
    end

    def self.tournament_packages
      where(%Q(name LIKE ?), '%Tournament Package')
    end

    def self.no_international
      find_by(%Q(description LIKE ?), '%International Flights')
    end

    def self.own_domestic
      find_by(name: [ 'Own Domestic', 'No Additional Airfare' ])
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    set_audit_methods!
  end
end
