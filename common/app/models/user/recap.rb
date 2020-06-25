# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

# User::Recap description
class User < ApplicationRecord
  class Recap < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    def serializable_hash(*)
      super.tap do |h|
        h['submitted_time'] = self.submitted_time
        h['name'] = self.user&.print_names
      end
    end

    attribute :in_queue_counts, :boolean

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :recaps
    delegate :staff, to: :user, allow_nil: true

    # == Validations ==========================================================
    validates_presence_of :log, message: "can't be blank; " \
                                          "fill out the summary " \
                                          "of your day before submitting"

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :set_created_at, unless: :in_queue_counts?
    after_commit :queue_counts, on: %i[ create update ], unless: :in_queue_counts?
    after_commit :touch_user

    # == Class Methods ========================================================

    # == Instance Methods =====================================================
    def submitted_time
      self.created_at&.strftime("%D @ %r")
    end

    def recap_midnight
      self.created_at&.midnight \
      || Time.zone.now.midnight
    end

    private
      def touch_user
        user.touch
      rescue
        true
      end

      def set_created_at
        if !self.created_at || (self.created_at > Time.zone.now.midnight)
          self.updated_at = self.created_at = Time.zone.now
        end

        true
      end

      def queue_counts
        return true unless self.persisted?

        if !self.created_at || (self.created_at > Time.zone.now.midnight)
          RecapCountJob.perform_later(self.id)
        end

        true
      end

      def set_counts
        self.in_queue_counts = true
        set_total_audits
        set_users_modified
        set_notes_made
        set_package_modifications

        save
      end

      def set_total_audits
        return self.total_audits = 0 unless user
        self.total_audits =
          self.user&.
            submitted_audits&.
            done_on(recap_midnight).
            count(1)
      end

      def set_users_modified
        return self.users_modified = 0 unless user
        self.users_modified =
          self.user.
            submitted_audits.
            done_on(recap_midnight).
            where(table_name: 'users').
            pluck(:row_id).uniq.size
      end

      def set_notes_made
        return self.notes_made = 0 unless self.user&.staff

        self.notes_made =
          self.user.staff.
            messages.
            done_on(recap_midnight).
            count(:all)
      end

      def set_package_modifications
        return self.notes_made = 0 unless self.user

        self.package_modifications =
          self.user.
            submitted_audits.
            done_on(recap_midnight).
            where(table_name: "traveler_debits").count(:all)
      end
  end
end
