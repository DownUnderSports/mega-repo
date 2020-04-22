# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff/assignment'

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    module Views
      class Traveler < Respond
        include WithDusId

        # == Constants ============================================================

        # == Attributes ===========================================================
        self.table_name = "assignments_travelers_view"

        # == Extensions ===========================================================

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
            name
            assigned_to_full_name
            assigned_by_full_name
            visited
            completed
            unneeded
            reviewed
            assigned_at
            message_count
            joined_at
            cancel_date
            admin_url
          ]
        end

        # == Boolean Methods ======================================================

        # == Instance Methods =====================================================

      end
    end
  end
end
