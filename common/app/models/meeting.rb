# encoding: utf-8
# frozen_string_literal: true

class Meeting < ApplicationRecord
  # == Constants ============================================================
  NON_DUPABLE_KEYS = Set.new(%i[ session_uuid recording_link join_link notes questions ])

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :host,
    class_name: 'User',
    optional: true

  belongs_to :tech,
    class_name: 'User',
    optional: true

  has_many :registrations,
    inverse_of: :meeting,
    dependent: :destroy

  has_many :athletes, through: :registrations
  has_many :users, through: :registrations

  # == Validations ==========================================================

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  scope :by_date, ->(date) { date = Time.zone.parse(date.to_s); where("start_time BETWEEN ? AND ?", date.midnight.utc, date.end_of_day.utc) }

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.default_print
    [
      :id,
      :start_time,
      :category,
      :registered,
      :attended,
      :webinar_uuid,
      :session_uuid,
    ]
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def registered
    registrations.size
  end

  def attended
    registrations.attended.size
  end

  def emails(current_scope = registrations, email_only = false)
    arr = current_scope.joins(:user).select('users.email', :user_id).order('users.email').map {|r| r.email.present? && [r.email, r.user_id] }.select(&:present?).uniq {|r| r.first }
    email_only ? arr.map(&:first) : arr
  end

  def attended_emails(email_only = false)
    emails registrations.attended, email_only
  end

  def missed_emails(email_only = false)
    emails registrations.missed, email_only
  end

  set_audit_methods!
end
