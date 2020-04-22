# # encoding: utf-8
# frozen_string_literal: true

class ShirtOrder < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :items, inverse_of: :shirt_order
  has_many :shipments, inverse_of: :shirt_order
  has_many :payments, inverse_of: :shirt_order

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

  set_audit_methods!
end
