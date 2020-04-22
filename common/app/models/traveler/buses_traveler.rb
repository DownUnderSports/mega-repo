# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

# Traveler::Bus description
class Traveler < ApplicationRecord
  class BusesTraveler < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.traveler_buses_travelers"

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Relationship Methods =================================================

    # == Instance Methods =====================================================

    set_audit_methods!
  end
end
