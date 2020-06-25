# encoding: utf-8
# frozen_string_literal: true

class Staff < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :messages, class_name: 'User::Message', inverse_of: :staff, dependent: :destroy do
    def done_today
      done_on(Time.zone.now.midnight)
    end

    def done_on(start_time, end_time = nil)
      where(arel_table[:created_at].gteq(start_time)).
      where(arel_table[:created_at].lteq(end_time || start_time.end_of_day))
    end
  end

  has_many :notes, class_name: 'User::Note', inverse_of: :staff, dependent: :destroy
  has_many :histories, class_name: 'User::History', inverse_of: :staff, dependent: :destroy
  has_many :contact_logs, class_name: 'User::ContactLog', inverse_of: :staff, dependent: :destroy
  has_many :contact_attempts, class_name: 'User::ContactAttempt', inverse_of: :staff, dependent: :destroy
  has_many :contact_histories, class_name: 'User::ContactHistory', inverse_of: :staff, dependent: :destroy
  has_many :alerts, class_name: 'User::Alert', inverse_of: :staff, dependent: :destroy
  has_many :clocks, inverse_of: :staff, dependent: :destroy

  has_one :user, as: :category

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  after_commit :touch_user, on: %i[ update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.default_print
    %i[
      id
      admin
      management
      trusted
      australia
      credits
      debits
      finances
      flights
      importing
      inventories
      meetings
      offers
      passports
      photos
      recaps
      remittances
      schools
      uniforms
    ]
  end

  # == Boolean Methods ======================================================
  def allowed?(permission)
    __send__(:"#{permission}?")
  end

  # == Instance Methods =====================================================
  def check(permission)
    allowed?(permission) || admin?
  end

  def add_clock
    clocks.create
  end

  def add_clock!
    clocks.create!
  end

  def clocks_since(since)
    clocks.
      where(
        "created_at >= ?",
        since ||
        clocks.order(:created_at).take&.created_at ||
        Time.zone.now
      ).
      order(:created_at)
  end

  def total_clock_time(since = nil)
    total = total_clocks_since(since)
    hours = (total - (total % 1.hour))
    total = total - hours
    "#{sprintf '%02d', (hours / 1.hour).to_i}:#{Time.zone.at(total).utc.strftime("%M:%S.%L")}"
  end

  def total_clock_decimal(since = nil)
    total_clocks_since(since) / 1.hour
  end

  def total_clocks_since(since = nil)
    start = nil
    total = 0
    clocks_since(since).
      split_batches_values(preserve_order: true) do |clock|
      if start
        total += clock.created_at.to_f - start
        start = nil
      else
        start = clock.created_at.to_f
      end
    end

    total += Time.zone.now.to_f - start if start

    total
  end

  private
    def touch_user
      user.touch
    rescue
      true
    end

  set_audit_methods!
end
