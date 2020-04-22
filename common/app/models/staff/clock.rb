# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff'

class Staff < ApplicationRecord
  class Clock < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :staff, inverse_of: :clocks

    # == Validations ==========================================================

    # == Scopes ===============================================================
    default_scope { default_order(:created_at) }

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    private
      def fix_time(new_time = Time.zone.now)
        self.class.where(id: self.id).update_all(created_at: new_time, updated_at: new_time)
      end

  end
end
