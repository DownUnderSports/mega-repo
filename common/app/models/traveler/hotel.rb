# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

# Traveler::Hotel description
class Traveler < ApplicationRecord
  class Hotel < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "public.traveler_hotels"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    has_many :buses, class_name: 'Traveler::Bus', inverse_of: :hotel
    has_many :rooms, class_name: 'Traveler::Room', inverse_of: :hotel do
      def unassigned
        where(number: nil)
      end
    end

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def flight_card
      "#{name} | #{address&.flight_card} | #{phone.presence}".strip.upcase
    end

    set_audit_methods!
  end
end

ValidatedAddresses
