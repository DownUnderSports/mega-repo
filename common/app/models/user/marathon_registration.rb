# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class MarathonRegistration < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :marathon_registration, touch: true

    # == Validations ==========================================================
    validates_presence_of :registered_date
    # validates_format_of :email, with: /\A[^@\s\;]+@[^@\s\;]+\.[^@\s\;]+\z/, allow_nil: true, allow_blank: true

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year

    # == Class Methods ========================================================

    # == Instance Methods =====================================================

  end
end
