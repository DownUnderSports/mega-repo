# encoding: utf-8
# frozen_string_literal: true

class CompetingTeamsTraveler < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.competing_teams_travelers"

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :competing_team, inverse_of: :competing_teams_travelers, touch: true
  belongs_to :traveler, inverse_of: :competing_teams_travelers, touch: true

  # == Validations ==========================================================
  before_save :check_active_year
  before_destroy :check_active_year

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

end
