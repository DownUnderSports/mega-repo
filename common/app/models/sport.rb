# encoding: utf-8
# frozen_string_literal: true

class Sport < ApplicationRecord
  include ClearCacheItems

  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_one :info, inverse_of: :sport
  has_many :athletes, inverse_of: :sport
  has_many :coaches, inverse_of: :sport
  has_many :athletes_sports, inverse_of: :sport
  has_many :competing_teams, inverse_of: :sport
  has_many :buses, class_name: 'Traveler::Bus', inverse_of: :sport
  has_many :hotels, class_name: 'Traveler::Hotel', inverse_of: :sport
  has_many :possible_athletes, through: :athletes_sports, source: :athlete, inverse_of: :possible_sports
  has_many :teams, inverse_of: :sport
  has_many :uniform_orders, inverse_of: :sport

  has_one_attached :standard

  accepts_nested_attributes_for :info
  delegate :title,  :tournament,  :first_year,  :departing_dates,  :team_count,  :team_size,  :description,  :bullet_points_array,  :additional, to: :info

  # == Validations ==========================================================
  validates :abbr, :full, presence: true

  validates :abbr_gender, :full_gender,
    presence: true,
    uniqueness: true

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.default_print
    [
      :id,
      :abbr_gender,
      :full_gender,
      :abbr,
      :full
    ]
  end

  def self.const_missing(name)
    const_set name, self[name] || super
  end

  def self.without_teams
    self.all.where_not_exists(:competing_teams)
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  # def travel_dates
  #   return @departing if @departing
  #   teams = Team.where(sport_id: self.id).
  #   order(:departing).
  #   group(:departing).
  #   pluck(:departing)
  #
  #   @departing = teams.size > 1 ? "#{teams.first.strftime("%A, %B %d, %Y")} and #{teams.last.strftime("%A %B %d, %Y")}" : teams.first.strftime("%A, %B %d, %Y")
  #
  #   @departing
  # end

    def rep
      REPS[self.abbr]
    end
  private
    def cache_match_str
      "sport.*(#{self.id}|#{self.abbr}|#{self.full})"
    end

    def should_clear_cache?
      true
    end

  set_audit_methods!
end
