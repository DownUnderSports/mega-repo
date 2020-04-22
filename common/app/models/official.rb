# encoding: utf-8
# frozen_string_literal: true

class Official < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :sport
  belongs_to :state

  has_one :user,
    as: :category,
    inverse_of: :category,
    dependent: :destroy,
    autosave: true,
    validate: true,
    required: false

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  after_commit :touch_user, on: %i[ update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def school
    # for compatibility with other main categories
    nil
  end

  def team
    Team.find_by(sport: sport, state: state)
  end

  def team=(team)
    t = Team[team]
    sport = t&.sport
    state = t&.state
    t
  end

  def wrong_school?
    nil
  end

  private
    def touch_user
      user.touch
    rescue
      true
    end

end
