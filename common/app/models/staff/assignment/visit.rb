# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff/assignment'

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    class Visit < ApplicationRecord
      # == Constants ============================================================

      # == Attributes ===========================================================

      # == Extensions ===========================================================

      # == Relationships ========================================================
      belongs_to :assignment,
        inverse_of: :visits

      delegate :view, to: :assignment

      # == Validations ==========================================================

      # == Scopes ===============================================================

      # == Callbacks ============================================================

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================

      # == Boolean Methods ======================================================

      # == Instance Methods =====================================================
      after_commit :refresh_view

      private
        def refresh_view
          view&.reload
          assignment&.touch

          true
        end

    end
  end
end
