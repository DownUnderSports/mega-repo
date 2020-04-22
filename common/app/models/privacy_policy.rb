# encoding: utf-8
# frozen_string_literal: true

# PrivacyPolicy description
class PrivacyPolicy < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :edited_by, class_name: 'User'

  # == Validations ==========================================================
  validates_presence_of :body

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.latest
    order(:id).last || new
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

end
