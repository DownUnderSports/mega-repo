# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class Message < ApplicationRecord
    # == Constants ============================================================
    CATEGORIES = []
    REASONS = []

    # == Attributes ===========================================================
    enum category: CATEGORIES.to_db_enum
    enum reason: REASONS.to_db_enum

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, touch: true
    belongs_to :staff

    # == Validations ==========================================================
    validates_presence_of :category, :reason, :message

    # == Scopes ===============================================================
    scope :premail_infokits, -> { where(message: 'Marked for infokit pre-mail') }
    scope :halloween_offers, -> { where(message: 'Sent Halloween Offer') }
    scope :fr_packets,       -> { where(message: 'Sent Fundraising Packet') }

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================
    after_commit :refresh_assignments, on: [ :create ]
    after_commit :set_responded_at, on: [ :create ]

    # == Class Methods ========================================================
    # def self.categories
    #   CATEGORIES
    # end
    #
    # def self.reasons
    #   REASONS
    # end

    def self.default_category(*)
      nil
    end

    def self.default_reason(*)
      nil
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def category=(cat)
      super(cat&.to_s&.underscore)
    end

    def reason=(r)
      super(r&.to_s&.underscore&.dasherize)
    end

    private
      def refresh_assignments
        reasons = nil
        if reasons = staff.user.assignments.unscoped.group(:reason).select(:reason).pluck(:reason)
          reasons.each do |r|
            staff.user.assignments.find_by(reason: r)&.view&.reload
          end
        end

        true
      rescue
        true
      end

      def set_responded_at
        user.responded_at(save: true) unless user.responded_at.present? || staff&.user&.id == auto_worker.id
        true
      end
  end
end
