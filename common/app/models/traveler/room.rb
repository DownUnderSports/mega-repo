# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

# Traveler::Room description
class Traveler < ApplicationRecord
  class Room < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.traveler_rooms"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :traveler, inverse_of: :rooms, touch: true
    belongs_to :hotel, class_name: 'Traveler::Hotel', inverse_of: :rooms, touch: true

    # == Validations ==========================================================
    validates_presence_of :check_in_date, :check_out_date

    validate :conflicting_dates

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def conflicting_dates
      has_conflict = false

      if check_in_date >= check_out_date
        errors.add(:base, "Conflicting Check-In/Check-Out Dates")
        return false
      else
        %i[
          check_in_date
          check_out_date
        ].each do |k|
          has_conflict ||=
            traveler.
              rooms.
              where.not(id: self.id).
              find_by(<<-SQL.gsub(/\s*\n?\s+/m, ' '),
                  (#{k} BETWEEN :check_in_date AND :check_out_date)
                SQL
                check_in_date: self.check_in_date + (k == :check_in_date ? 0 : 1),
                check_out_date: self.check_out_date - (k == :check_out_date ? 0 : 1),
              ) \
            && k
        end
      end

      if has_conflict
        errors.add(:base, "#{has_conflict == :check_in_date ? 'Check-In' : 'Check-Out' } Date Conflicts With Another Rooming")
        return false
      end

      true
    end

    set_audit_methods!
  end
end
