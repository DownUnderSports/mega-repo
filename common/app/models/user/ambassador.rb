# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class Ambassador < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :ambassador_records, touch: true
    belongs_to :ambassador, class_name: 'User', foreign_key: :ambassador_user_id

    # == Validations ==========================================================
    validate :not_ambassador_to_self

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.new(*args)
      super.tap do |r|
        r.types_array = [] unless r.types_array.is_a?(Array)
      end
    end
    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    private
      def not_ambassador_to_self
        errors.add(:user_id, "can't be an ambassador to themself") if (self.user_id == self.ambassador_user_id) && (self.user == self.ambassador)
      end

    set_audit_methods!
  end
end
