# encoding: utf-8
# frozen_string_literal: true

module Current
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  def self.user
    BetterRecord::Current.user
  end

  def self.user=(user)
    set(user, BetterRecord::Current.ip_address)
  end

  def self.ip_address
    BetterRecord::Current.ip_address
  end

  def self.ip_address=(ip)
    set(BetterRecord::Current.ip_address, ip)
  end

  def self.user_type
    BetterRecord::Current.user_type
  end

  def self.set(user, ip)
    BetterRecord::Current.set(user, ip)
  end

  def self.drop_values
    BetterRecord::Current.drop_values
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

end
