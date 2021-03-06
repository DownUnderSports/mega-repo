# encoding: utf-8
# frozen_string_literal: true

require_dependency 'shirt_order'

class ShirtOrder < ApplicationRecord
  class Shipment < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :shirt_order, inverse_of: :shipment, touch: true

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    set_audit_methods!
  end
end
