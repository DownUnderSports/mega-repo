# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

module Accounting
  module Views
    class User < ::User
      # == Constants ============================================================

      # == Attributes ===========================================================
      # self.table_name = "#{usable_schema_year}.accounting_users_view"
      self.table_name = "accounting_users_view"

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
          id
          dus_id
          basic_name
          category_type
          total_paid
          total_debited
          total_credited
          current_balance
        ]
      end

      # == Boolean Methods ======================================================

      # == Instance Methods =====================================================
      def total_charges
        self[:total_charges] || traveler&.total_charges
      end
    end
  end
end
