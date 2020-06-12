# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/contact_log'

class User < ApplicationRecord
  class InterestHistory < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user
    belongs_to :interest
    belongs_to :changed_by, optional: true, class_name: "User"

    # == Validations ==========================================================

    # == Scopes ===============================================================
    default_scope { default_order(created_at: :desc) }

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
