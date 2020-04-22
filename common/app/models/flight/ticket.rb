# encoding: utf-8
# frozen_string_literal: true

module Flight
  class Ticket < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.flight_tickets"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :schedule, class_name: 'Flight::Schedule', inverse_of: :tickets
    belongs_to :traveler, class_name: 'Traveler', inverse_of: :tickets

    has_one :user, through: :traveler, inverse_of: :tickets

    has_many :flight_legs,
      through: :schedule,
      source: :legs,
      inverse_of: :tickets

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year
    before_destroy :check_required
    after_commit :touch_user

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    private
      def check_required
        if self.required?
          errors.add(:required, "ticket can't be removed")
          throw :abort
        end
      end

      def touch_user
        traveler&.touch
        traveler&.user&.touch
        true
      end

    set_audit_methods!
  end
end
