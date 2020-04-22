# encoding: utf-8
# frozen_string_literal: true

class Meeting < ApplicationRecord
  class Video < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :host,
      class_name: 'User',
      optional: true

    belongs_to :tech,
      class_name: 'User',
      optional: true

    has_many :views,
      inverse_of: :video,
      dependent: :destroy

    has_many :athletes, through: :views
    has_many :users, through: :views

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

    def minimum_duration
      Time.
        at(self.duration.to_d * self.minimum_percentage.to_d).
        utc.
        strftime("%H:%M:%S")
    end

    def minimum_duration=(time)
      self.minimum_percentage = time.to_d / self.duration.to_d
      self.minimum_duration
    end

    set_audit_methods!
  end
end
