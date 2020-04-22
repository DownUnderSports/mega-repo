# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/message'

class User < ApplicationRecord
  class ContactLog < Message
    # == Constants ============================================================
    CATEGORIES = %i[ e_t_c_lm email call text ].freeze
    REASONS = %i[ pre-meeting post-meeting other ].freeze

    # == Attributes ===========================================================
    enum category: CATEGORIES.to_db_enum
    enum reason: REASONS.to_db_enum

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_validation :reviewed

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.default_reason(user = nil)
      if user.traveler
        'other'
      elsif user&.video_views&.watched&.exists?
        'post-meeting'
      elsif user&.responded_at?
        'pre-meeting'
      else
        'other'
      end
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def reviewed
      begin
        write_attribute :reviewed, true
      rescue RuntimeError
        p 'Destroyed'
      end
      true
    end

    def reviewed=(*args)
      super(true)
    end
  end
end
