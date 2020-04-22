# encoding: utf-8
# frozen_string_literal: true

class Participant < ApplicationRecord
  include ClearCacheItems

  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :state
  belongs_to :sport, optional: true

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  after_commit :refresh_view

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def refresh_view
    Views::Map.reload
    true
  end

  def cache_match_str
    "participant.*"
  end

  def should_clear_cache?
    true
  end

end
