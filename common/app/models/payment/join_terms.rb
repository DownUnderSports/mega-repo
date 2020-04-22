# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

class Payment < ApplicationRecord
  class JoinTerms < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :terms, class_name: 'Payment::Terms'
    belongs_to :payment

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
