# encoding: utf-8
# frozen_string_literal: true

require_dependency 'staff'

class Staff < ApplicationRecord
  class Assignment < ApplicationRecord
    include WithDusId
    # == Constants ============================================================

    # == Attributes ===========================================================
    attribute :visited, :boolean

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :assigned_to, class_name: 'User', inverse_of: :assignments
    belongs_to :assigned_by, class_name: 'User', inverse_of: :assignments_made
    belongs_to :user, touch: true

    has_many :visits,
      dependent: :destroy

    # == Validations ==========================================================
    validate :locked_staff_changed, on: [ :update ]
    validate :can_mark_complete

    # == Scopes ===============================================================
    scope :travelers, -> { where(reason: 'Traveler') }
    scope :responds, -> { where(reason: 'Respond') }
    scope :completed, -> { where(completed: true) }
    scope :complete, -> { completed }
    scope :incomplete, -> { where(completed: false) }
    scope :uncompleted, -> { incomplete }
    scope :unneeded, -> { where(unneeded: true) }

    # == Callbacks ============================================================
    before_validation :set_times
    before_save :check_active_year
    before_destroy :check_active_year
    after_commit :assignment_created_or_destroyed, on: [ :create, :destroy ]
    after_commit :refresh_view, on: [ :update ]
    after_commit :notify_completed, on: [ :update ]

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================
    def is_respond?
      reason == 'Respond'
    end

    def is_traveler?
      reason == 'Traveler'
    end

    # == Instance Methods =====================================================

    def assigned_at
      created_at
    end

    def dus_id
      formatted_dus_id self[:dus_id] || user.dus_id
    end

    def view
      Views.const_get(self.reason.to_s.classify)
    rescue NameError
      nil
    end

    def unassigned_view
      Views.const_get("Unassigned#{self.reason.to_s}".classify)
    rescue NameError
      nil
    end

    def visited
      visits.any?
    end

    def visited=(val)
      self.updated_at = Time.zone.now
      if Boolean.parse(val)
        !!visits.create
      else
        visits.delete_all
        view&.reload
        false
      end
    end

    private
      def locked_staff_changed
        if locked? && assigned_to_id_changed?
          errors.add(:assigned_to_id, "Reassigning locked records not allowed")
          throw :abort
        end
      end

      def can_mark_complete
        if completed?
          if is_respond?
            if !user.traveler
              errors.add(:completed, "Responds cannot be marked completed")
              throw :abort
            end
          elsif is_traveler?
            if !user.traveler&.cancel_date
              errors.add(:completed, "Travelers cannot be marked completed unless they have canceled")
              throw :abort
            end
          end
        end
      end

      def set_times
        %i[
          unneeded
          completed
          reviewed
        ].each do |k|
          if self[k]
            self[:"#{k}_at"] ||= Time.zone.now
          else
            self[:"#{k}_at"] = nil
          end
        end
        true
      end

      def refresh_view
        v = nil
        v.reload if (
          previous_changes['reason'] ||
          previous_changes['follow_up_date'] ||
          previous_changes['completed'] ||
          previous_changes['unneeded'] ||
          previous_changes['assigned_to_id'] ||
          previous_changes['locked'] ||
          previous_changes['visited']
        ) && (v = self.view)

        true
      end

      def assignment_created_or_destroyed
        self.view&.reload
        self.unassigned_view&.reload
        true
      end

      def notify_completed
        if completed && previous_changes[:completed]
          StaffMailer.with(id: self.id).assignment_completed.deliver_later(queue: :staff_mailer) if !is_respond? || !user.traveler
        end
      end
  end
end
