# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff/assignment'
require_dependency 'user'

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    module Views
      class UnassignedRespond < User
        # == Constants ============================================================

        # == Attributes ===========================================================
        # self.table_name = "#{usable_schema_year}.assignments_unassigned_responds_view"
        self.table_name = "assignments_unassigned_responds_view"

        # == Extensions ===========================================================
        include MaterializedViewExtensions

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
            duration
            watched_at
            viewed_at
            registered_at
            state_abbr
            sport_abbr
            tz_offset
            responded_at
          ]
        end

        # == Boolean Methods ======================================================

        # == Instance Methods =====================================================

      end
    end
  end
end
