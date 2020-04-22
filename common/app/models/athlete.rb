# encoding: utf-8
# frozen_string_literal: true

class Athlete < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :school,inverse_of: :athletes, validate: true
  belongs_to :source, inverse_of: :athletes, validate: true
  belongs_to :sport, inverse_of: :athletes, optional: true
  belongs_to :competing_team, inverse_of: :athletes, optional: true
  belongs_to :referring_coach,
    foreign_key: :referring_coach_id,
    class_name: 'Coach',
    inverse_of: :referred_athletes,
    optional: true
  belongs_to :student_list,
    foreign_key: :student_list_date,
    primary_key: :sent,
    inverse_of: :athletes,
    optional: true

  has_one :school_address, through: :school, source: :address
  has_one :user,
    as: :category,
    inverse_of: :category,
    dependent: :destroy,
    autosave: true,
    validate: true,
    required: false

  has_many :athletes_sports, inverse_of: :athlete, dependent: :destroy
  has_many :possible_sports, through: :athletes_sports, source: :sport, inverse_of: :possible_athletes

  accepts_nested_attributes_for :athletes_sports

  # == Validations ==========================================================
  validates :athletes_sports, presence: { message: 'Athletes must have at least one sport' }

  # == Scopes ===============================================================
  default_scope { default_order(:id) }
  scope :with_teams, ->(options = nil) { join_teams(nil, options) }

  # == Callbacks ============================================================
  before_validation :fetch_school
  after_commit :set_user_visibility
  after_commit :touch_user, on: %i[ update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.join_teams(team_table_name = nil, options = nil)
    time = "#{Time.now.to_i}"
    sch_name = "athlete_team_schools_#{time}#{rand(1000..9000)}"
    ad_name = "athlete_team_school_addresses_#{time}"

    if team_table_name.present?
      tm_name = "teams #{team_table_name}"
    else
      team_table_name = tm_name = "teams"
    end

    query = joins(
      <<-SQL
        INNER JOIN schools #{sch_name}
        ON #{sch_name}.id = athletes.school_id
        INNER JOIN addresses #{ad_name} ON
        #{ad_name}.id = #{sch_name}.address_id
        INNER JOIN #{tm_name} ON
        (
          (#{team_table_name}.state_id = #{ad_name}.state_id)
          AND
          (#{team_table_name}.sport_id = athletes.sport_id)
        )
      SQL
    )
    options.present? ? query.where("#{team_table_name}" => options) : query
  end

  # == Boolean Methods ======================================================
  def wrong_school?
    school_id == wrong_school&.id
  end

  # == Instance Methods =====================================================
  def team
    user&.team ||
    Team.find_by(state_id: school_address.state_id, sport_id: sport.id) if sport.present? && school_address.present?
  end

  alias :super_sport :sport

  def sport(reload = false)
    @athlete_sport = nil if reload
    @athlete_sport ||= super_sport || athletes_sports.order(:rank).first&.sport
  end

  def wrong_school!
    user.mailings.where(is_home: false, failed: false, street: school.address&.street).each do |m|
      m.update(failed: true)
    end
    self.original_school_name ||= school.name
    self.school = wrong_school
    save!
  end

  alias :super_reload :reload

  def reload
    @athlete_sport = nil
    super_reload
  end

  def grad_visibility
    grad ?
      grad + 1 :
      [
        user.visible_until_year&.to_i,
        current_year.to_i + 1
      ].select(&:present?).presence&.min
  end

  private
    def set_user_visibility
      if previous_changes.key?(:grad) || previous_changes.key?("grad")
        user.set_visibility(grad_visibility)
      end
    end

    def touch_user
      user.touch
    rescue
      true
    end

    def fetch_school
      if self.txfr_school_id.present? && !self.school
        self.school = School.import_from_transfer_id(self.txfr_school_id)
      end
      true
    end

  set_audit_methods!
end
