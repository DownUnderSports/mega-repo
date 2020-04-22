# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

class Payment < ApplicationRecord
  class Item < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.payment_items"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :payment, touch: true
    belongs_to :traveler, optional: true, touch: true

    # == Validations ==========================================================
    validates_presence_of :amount, :name

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_commit :run_offers_check
    after_commit :set_traveler_details

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def run_offers_check
      i = self.class.find_by(id: self.id)
      Traveler::OffersCheckJob.perform_later(i.traveler_id) if i&.traveler_id.present?
      true
    end

    private
      def set_traveler_details
        traveler&.set_details(
          should_set_airports: false,
          should_set_balance: true,
          should_save_details: true,
        ) if previous_changes[:amount]
      end

    set_audit_methods!
  end
end
