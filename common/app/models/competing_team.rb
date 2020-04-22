# encoding: utf-8
# frozen_string_literal: true

class CompetingTeam < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.competing_teams"

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :sport, inverse_of: :competing_teams

  # has_many :coaches, inverse_of: :competing_team, dependent: :nullify
  # has_many :assitant_coaches, through: :coaches
  has_many :teams, inverse_of: :competing_team
  has_and_belongs_to_many :travelers, inverse_of: :competing_teams, after_add: :touch_updated_at, after_remove: :touch_updated_at do
    def active
      where(cancel_date: nil)
    end

    def athletes
      joins(:user).where(cancel_date: nil, users: { category_type: :athletes })
    end

    def coaches
      joins(:user).where(cancel_date: nil, users: { category_type: :coaches })
    end

    def others
      joins(:user).where(cancel_date: nil).where.not(users: { category_type: [ nil, :coaches, :athletes ] })
    end

    def supporters
      joins(:user).where(cancel_date: nil, users: { category_type: nil })
    end
  end

  # == Validations ==========================================================
  validates :sport_id, presence: true
  validates :name, :letter,
    presence: true,
    uniqueness: { scope: :sport_id }

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  before_save :check_active_year
  before_destroy :check_active_year

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Relationship Methods =================================================
  def athletes
    travelers.athletes
  end

  def athlete_users
    athletes.map(&:user)
  end

  def coaches
    travelers.coaches
  end

  def coach_users
    coaches.map(&:user)
  end

  def others
    travelers.others
  end

  def other_users
    others.map(&:user)
  end

  def supporters
    travelers.supporters
  end

  def supporter_users
    supporters.map(&:user)
  end

  # == Instance Methods =====================================================
  def to_str
    "#{self.sport.abbr_gender} - #{self.name} (#{self.letter})"
  end

  def sport_abbr
    sport&.abbr_gender
  end

  def touch_updated_at(traveler = nil)
    begin
      traveler&.touch
      traveler&.user&.touch
    rescue
    end
    self.touch if persisted?
  end

  def coach_names
    names = coach_users.map(&:basic_name).sort
    names.join(", ").sub(/, ([^,]+)$/, ' and \1')
  end

end
