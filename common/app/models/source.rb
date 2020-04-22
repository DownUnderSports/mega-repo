# encoding: utf-8
# frozen_string_literal: true

class Source < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :athletes, inverse_of: :source

  # == Validations ==========================================================
  validates :name, presence: true, uniqueness: true

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  # == Callbacks ============================================================
  before_save :titleize

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.get_or_create(name)
    Source.find_by(name: name&.titleize) || Source.create(name: name)
  end

  def self.get_or_create!(name)
    Source.find_by(name: name&.titleize) || Source.create!(name: name)
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

  private
    def titleize
      self.name = name&.titleize.presence
    end

  set_audit_methods!
end
