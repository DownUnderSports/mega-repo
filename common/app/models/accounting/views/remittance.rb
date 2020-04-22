# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/remittance'

module Accounting
  module Views
    class Remittance < ::Payment::Remittance
      # == Constants ============================================================

      # == Attributes ===========================================================
      # self.table_name = "#{usable_schema_year}.accounting_remit_forms_view"
      self.table_name = "accounting_remit_forms_view"

      # == Extensions ===========================================================
      include MaterializedViewExtensions

      # == Relationships ========================================================

      # == Validations ==========================================================

      # == Scopes ===============================================================

      # == Callbacks ============================================================

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================
      def self.default_print
        %i[
          remit_number
          positive_amount
          negative_amount
          net_amount
          successful_amount
          failed_amount
          recorded
          reconciled
        ]
      end

      # == Boolean Methods ======================================================

      # == Instance Methods =====================================================

    end
  end
end
