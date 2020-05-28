# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

# User::TransferExpectation description
class User < ApplicationRecord
  class TransferExpectation < ApplicationRecord
    # == Constants ============================================================
    DIFFICULTIES =
      %w[ extreme hard moderate easy none ].
        each_with_object({}) {|cat, obj| obj[cat] = cat}.
        freeze

    STATUSES =
      %w[ evaluated contacted confirmed completed ].
        each_with_object({}) {|cat, obj| obj[cat] = cat}.
        freeze
    # == Attributes ===========================================================
    enum difficulty: self::DIFFICULTIES, _suffix: :difficulty
    enum status: self::STATUSES, _suffix: :status

    attribute :staff_user_id, :integer
    attribute :can_revert, :boolean

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :transfer_expectation

    # == Validations ==========================================================
    validates :difficulty, inclusion: { in: difficulties.keys }, allow_nil: true
    validates :status, inclusion: { in: statuses.keys }, allow_nil: true
    validate :check_changes

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_changes
    after_commit :refresh_views
    after_commit :send_confirmations, on: %i[ create update ]

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================
    def allow_revert?
      can_confirm? &&
      can_revert
    end

    def allow_confirm?
      can_confirm? &&
      can_transfer.in?(%w[ Y N ])
    end

    def can_confirm?
      changed_by&.staff&.check(:admin)
    end

    # == Instance Methods =====================================================
    private
      def refresh_views
        user.touch
        User::Views::Index.reload
      end

      def check_changes
        unless allow_revert?
          if status_was.in? protected_statuses
            unless allow_revert? || status.in?(protected_statuses)
              errors.add(:status, 'revert not allowed')
            end
            unless allow_confirm?
              if can_confirm?
                errors.add(:status, "cannot be confirmed when it's unknown if they can transfer")
              else
                errors.add(:base, 'changes not allowed without permission')
              end
            end
          elsif status.in?(protected_statuses)
            unless allow_confirm?
              errors.add(:status, 'upgrade not allowed')
            end
          end
        end
      end

      def changed_by
        User[self.staff_user_id]
      end

      def protected_statuses
        @protected_statuses ||= %w[ confirmed completed ].freeze
      end

      def mind_changed?
        self.confirmed_status? &&
        (
          previous_changes.key?("can_transfer") ||
          previous_changes.key?(:can_transfer)
        )
      end

      def send_confirmations
        if previous_changes.key?(:status) || previous_changes.key?("status") || mind_changed?
          if self.confirmed_status?
            self.class.transaction do
              if self.can_transfer == 'Y'
                unless self.user.is_deferral?
                  self.user.notes.create!(message: 'Deferral to 2021', category: :note, reason: :other, staff_id: auto_worker.category_id)
                end
                unless self.user.traveler.canceled?
                  self.user.traveler.update!(cancel_date: Date.today)
                end
                if self.user.can_send_transfer? || mind_changed?
                  self.user.send_transfer_email
                end
              elsif self.can_transfer == 'N'
                if self.user.is_deferral?
                  self.user.notes.find_by(message: 'Deferral to 2021')&.destroy!
                end
                unless self.user.traveler.canceled?
                  self.user.traveler.update!(cancel_date: Date.today)
                end
                if self.user.can_send_cancellation? || mind_changed?
                  self.user.send_cancellation_email
                  UserMailer.
                    with(
                      user_id: self.user_id,
                      staff_user_id: (changed_by || auto_worker).id
                    ).
                    cancel.
                    deliver_later(queue: :staff_mailer)
                end
              end
            end
          end
        end
      rescue
        nil
      end

  end
end
