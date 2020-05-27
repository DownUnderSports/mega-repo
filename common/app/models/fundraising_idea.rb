# encoding: utf-8
# frozen_string_literal: true

# FundraisingIdea description
class FundraisingIdea < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  has_many :images, inverse_of: :fundraising_idea, dependent: :destroy

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Validations ==========================================================

  # == Scopes ===============================================================
  scope :ordered, -> { order(display_order: :asc, created_at: :asc) }
  scope :with_attached_images, -> {
    includes(:images).merge(Image.with_attached_file)
  }

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

end
