# encoding: utf-8
# frozen_string_literal: true

class Coach < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :school, inverse_of: :athletes, optional: true
  belongs_to :sport, inverse_of: :coaches, optional: true
  belongs_to :head_coach, class_name: 'Coach', optional: true, inverse_of: :assitant_coaches
  # belongs_to :competing_team, optional: true, inverse_of: :coaches, touch: true

  has_one :school_address, through: :school, source: :address
  has_one :user,
    as: :category,
    inverse_of: :category,
    dependent: :destroy,
    autosave: true,
    validate: true,
    required: false

  has_many :assitant_coaches,
    foreign_key: :head_coach_id,
    class_name: 'Coach',
    dependent: :nullify
  has_many :referred_athletes,
    foreign_key: :referring_coach_id,
    class_name: 'Athlete',
    inverse_of: :referring_coach,
    dependent: :nullify

  # == Validations ==========================================================

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  # == Callbacks ============================================================
  after_commit :touch_user, on: %i[ update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================
  def wrong_school?
    school_id == wrong_school&.id
  end

  # == Instance Methods =====================================================
  def team
    user&.team ||
    Team.find_by(state_id: school_address.state_id, sport_id: sport_id) if sport_id? && school&.address.present?
  end

  def wrong_school!
    user.mailings.where(is_home: false, failed: false, street: school.address&.street).each do |m|
      m.update(failed: true)
    end
    self.original_school_name ||= school.name
    self.school = wrong_school
    save!
  end

  private
    def touch_user
      user.touch
    rescue
      true
    end

  set_audit_methods!
end
