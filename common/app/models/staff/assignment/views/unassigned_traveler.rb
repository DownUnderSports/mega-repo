# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff/assignment'
require_dependency 'user'

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    module Views
      class UnassignedTraveler < UnassignedRespond
        # == Constants ============================================================

        # == Attributes ===========================================================
        # self.table_name = "#{usable_schema_year}.assignments_unassigned_travelers_view"
        self.table_name = "assignments_unassigned_travelers_view"

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
            basic_name
            state_abbr
            sport_abbr
            joined_at
            cancel_date
          ]
        end

        # == Boolean Methods ======================================================

        # == Instance Methods =====================================================

      end
    end
  end
end
