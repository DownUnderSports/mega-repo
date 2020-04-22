# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

class Payment < ApplicationRecord
  class Remittance < ApplicationRecord

    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.payment_remittances"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    has_many :payments, foreign_key: 'remit_number', primary_key: 'remit_number', inverse_of: :remittance
    has_many :items, through: :payments

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
