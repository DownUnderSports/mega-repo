# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler'

class Traveler < ApplicationRecord
  class Credit < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.traveler_credits"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :traveler, inverse_of: :credits, touch: true
    belongs_to :assigner, class_name: 'User', optional: true

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_validation :founders_day_settings
    after_commit :set_insurance

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.categories
      group(:name).order(:name).select(:name, 'COUNT(id) AS count', 'MAX(amount) AS largest', 'MIN(amount) AS smallest')
    end

    def self.category_description(name)
      where(name: name).group(:description).distinct.select(:description).length == 1 ?
        where(name: name).limit(1).take.description.presence :
        nil
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    private
      def set_traveler_details
        traveler&.set_details(
          should_set_airports: false,
          should_set_balance: true,
          should_save_details: true,
        ) if previous_changes[:amount]
      end

      def set_insurance
        traveler&.set_insurance_price
      end

      def founders_day_settings
        if name.to_s =~ /^founder\'?s\'? day/i
          self.name = 'Founders Day Discount'
          self.amount = 1499_00.cents
          self.description = 'Australia Tournament Package for $3200'
        end
        true
      end

    set_audit_methods!
  end
end
