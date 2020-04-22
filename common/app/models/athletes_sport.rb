# encoding: utf-8
# frozen_string_literal: true

class AthletesSport < ApplicationRecord
  # == Constants ============================================================
  TRANSFERABILITIES =
    %w[ always necessary none ].
      each_with_object({}) {|cat, obj| obj[cat] = cat}.
      merge({ "nil" => nil }).
      freeze

  # == Attributes ===========================================================
  enum transferability: self::TRANSFERABILITIES, _prefix: :transfer

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :athlete, inverse_of: :athletes_sports, touch: true
  belongs_to :sport, inverse_of: :athletes_sports

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================
  def transfer_nil?
    transferability.nil?
  end

  # == Instance Methods =====================================================

  set_audit_methods!
end
