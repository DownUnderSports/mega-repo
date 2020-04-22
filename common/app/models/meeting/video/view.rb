# encoding: utf-8
# frozen_string_literal: true

class Meeting < ApplicationRecord
  class Video < ApplicationRecord
    class View < ApplicationRecord
      # == Constants ============================================================

      # == Attributes ===========================================================
      # self.table_name = "#{usable_schema_year}.meeting_video_views"

      # == Extensions ===========================================================

      # == Relationships ========================================================
      belongs_to :video
      belongs_to :user
      belongs_to :athlete, optional: true

      delegate :category, to: :video

      # == Validations ==========================================================
      validates_uniqueness_of :video_id, scope: :user_id

      # == Scopes ===============================================================
      default_scope { default_order(:video_id, :id) }

      scope :watched, -> { where(watched: true) }
      scope :unwatched, -> { where(watched: false) }

      # == Callbacks ============================================================
      before_validation :set_dates
      before_save :check_active_year
      before_destroy :check_active_year
      after_commit :run_checks, on: %i[ create update ]

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================
      def self.first_viewed(view)
        viewed_changes(view).limit(1).
          select(
            %(COALESCE(changed_fields->'updated_at', row_data->'updated_at')::timestamp first_viewed)
          ).
          take&.first_viewed&.in_time_zone
      end

      def self.first_watched(view)
        watched_changes(view).limit(1).
          select(
            %(COALESCE(changed_fields->'updated_at', row_data->'updated_at')::timestamp first_watched)
          ).
          take&.first_watched&.in_time_zone
      end

      def self.viewed_changes(view = nil)
        changed = logged_actions.where.not(%(row_data->'duration' = '00:00:00')).where(%(action = 'I')).
          or( logged_actions.where(%(changed_fields ? 'duration')) ).
          order( :event_id )

        view ? changed.where(%(row_data->'id' = ?), view.id.to_s) : changed
      end

      def self.watched_changes(view = nil)
        changed = logged_actions.where(%((row_data->'watched' = 't') AND (action = 'I'))).
          or( logged_actions.where(%((changed_fields->'watched' = 't') AND (action = 'U'))) ).
          order( :event_id )

        view ? changed.where(%(row_data->'id' = ?), view.id.to_s) : changed
      end

      # == Boolean Methods ======================================================
      def allowed_offers?
        #'Meeting::Video::View[:id][first_watched]-2'
        !!(
          !gave_offer? &&
          video.offer.present? &&
          (
            !user.traveler ||
            (
              user.traveler.credits.
              where(name: video.offer_exceptions_array).count == 0
            )
          ) &&
          (
            user.offers.
            where(name: video.offer_exceptions_array).
            count == 0
          )
        )
      end

      def gave_offer?
        !!self.gave_offer
      end

      # == Instance Methods =====================================================
      def category_title
        Meeting::Category.titleize(category || 'i')
      end

      def first_viewed
        self.first_viewed_at ||= get_first_viewed.presence
      rescue
        nil
      end

      def first_watched
        self.first_watched_at ||= get_first_watched.presence
      rescue
        nil
      end

      def last_viewed
        self.last_viewed_at ||= first_viewed ? updated_at : nil
      rescue
        nil
      end

      def run_checks
        watched ? run_offers_check : run_email_checks
        true
      end

      def run_email_checks
        if user.email.present?
          if !(user.contact_histories.find_by(message: video_message))
            video_email
          else
            'Too Early'
          end
        else
          'No Email'
        end
      end

      def run_offers_check
        if allowed_offers?
          begin
            self.class.transaction do
              self.class.find_by(id: self.id).update!(gave_offer: true)
              offer = video.offer.dup.deep_symbolize_keys
              offer[:rules].map! do |r|
                r.
                  gsub(':id', self.id.to_s).
                  gsub(':view_id', self.id.to_s).
                  gsub(':video_id', self.video_id.to_s).
                  gsub(':user_id', self.user_id.to_s)
              end

              User.find_by(id: user.id).offers.create!(
                assigner: auto_worker,
                **offer
              )

              video_watched_email
            end
          rescue
            self.class.find_by(id: self.id).update(gave_offer: false)
          end
        end
      end

      def track(duration: 0, played: nil)
        new_duration = [self.duration.to_i, duration.to_i].max
        new_watched = played.to_d >= self.video&.minimum_percentage.to_d
        new_viewed_at = Time.zone.now
        new_watched_at = watched ? Time.zone.now : nil

        new_duration, new_watched, new_viewed_at, new_watched_at, new_last_viewed_at =
          self.values_from_sidekiq(
            new_duration,
            new_watched,
            new_viewed_at,
            new_watched_at,
            new_viewed_at
          )

        Meeting::Video::TrackJob.
          set(wait_until: 2.minutes.from_now).
          perform_later(
            self,
            new_duration,
            new_viewed_at,
            new_watched,
            new_watched_at,
            new_last_viewed_at
          )

        [
          new_duration.to_i,
          self.watched || new_watched,
          self.user&.offers&.find_by(amount: 200_00)&.expiration_date ||
          Date.new(2020,4,12),
            # ((self.first_watched_at || new_watched_at || Time.zone.now) + 2.days).to_date,
          ((self.first_watched_at || new_watched_at || Time.zone.now) + 2.weeks).to_date
        ]
      end

      def values_from_sidekiq(new_duration, new_watched, new_viewed_at, new_watched_at, new_last_viewed_at = Time.zone.now)
        [Sidekiq::ScheduledSet, Sidekiq::RetrySet].each do |ss_klass|
          ss_klass.new.scan("Meeting::Video::TrackJob").select do |job|
            args = job.args[0] || {}
            if args['job_class'] == 'Meeting::Video::TrackJob'
              arguments = args['arguments']
              if arguments[0]['_aj_globalid'].to_s =~ /\/(#{same_video_ids.join('|')})$/
                new_duration = [new_duration, arguments[1].to_i].max
                new_viewed_at = [
                  GlobalID::Locator.locate(arguments[2]['_aj_globalid']),
                  new_viewed_at
                ].min

                new_watched ||= Boolean.parse(arguments[3])
                if new_watched && arguments[4]
                  new_watched_at = [
                    GlobalID::Locator.locate(arguments[4]['_aj_globalid']),
                    new_watched_at
                  ].min
                end

                if arguments[5]
                  new_last_viewed_at = [
                    GlobalID::Locator.locate(arguments[5]['_aj_globalid']),
                    new_last_viewed_at
                  ].max
                end

                true
              else
                false
              end
            else
              false
            end
          end.each(&:delete)
        end

        [ new_duration, new_watched, new_viewed_at, new_watched_at, new_last_viewed_at ]
      end

      def video_email
        if Meeting::VideoMailer.respond_to?(category_title.downcase)
          Meeting::VideoMailer.
          with(
            video_id: video_id,
            email: user.email,
            user_id: user.id,
            message: video_message,
            history_id: user.contact_histories.create(
              category: :email,
              message: video_message,
              staff_id: auto_worker.category_id
            )&.id
          ).__send__(category_title.downcase).deliver_later
        end
      end

      def video_watched_email
        if Meeting::VideoMailer.respond_to?("#{category_title.downcase}_watched")
          Meeting::VideoMailer.
          with(
            video_id: video_id,
            email: user.athlete_and_parent_emails,
            user_id: user.id,
            message: video_watched_message,
            history_id: user.contact_histories.create(
              category: :email,
              message: video_watched_message,
              staff_id: auto_worker.category_id
            )&.id
          ).__send__("#{category_title.downcase}_watched").deliver_later
        end
      end

      def video_message
        "Sent email for #{category_title} Video (#{video_id}) to #{user.email}"
      end

      def video_watched_message
        "Sent watched email for #{category_title} Video (#{video_id})"
      end

      def viewed_changes
        self.class.viewed_changes(self) if self.id
      end

      def watched_changes
        self.class.watched_changes(self) if self.id
      end

      def same_video_ids
        self.class.where(video_id: self.video_id, user_id: self.user_id).order(:id).pluck(:id)
      end

      private

        def set_dates
          first_viewed
          first_watched
          if watched && (self.duration.to_i == 0)
            self.duration = video&.duration
            self.first_viewed_at ||= Time.zone.now
            self.first_watched_at ||= Time.zone.now
          end

          if (self.duration.to_i == 0)
            self.last_viewed_at = nil
          else
            self.last_viewed_at ||= Time.zone.now
          end

          true
        end

        def get_first_viewed
          if (self.duration.to_i != 0)
            (
              (
                self.id &&
                (self.duration_was.to_i == self.duration.to_i) &&
                self.class.first_viewed(self)
              ) ||
              Time.zone.now
            ).presence
          elsif self.watched
            self.duration = video&.duration
            first_watched
          end
        rescue
          nil
        end

        def get_first_watched
          (
            self.watched &&
            (
              (
                self.id &&
                !!self.watched_was &&
                self.class.first_watched(self)
              ) ||
              Time.zone.now
            )
          ).presence
        rescue
          nil
        end

      set_audit_methods!
    end
  end
end
