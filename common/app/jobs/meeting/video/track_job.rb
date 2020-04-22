# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting/video'

class Meeting < ApplicationRecord
  class Video < ApplicationRecord
    class TrackJob < ApplicationJob
      queue_as :video_tracking

      # discard_on ActiveJob::DeserializationError

      def perform(view, duration, viewed_at, watched, watched_at, last_viewed_at = Time.zone.now, *args)
        return false unless view

        if (same_video_ids = view.same_video_ids).size > 1
          main_view = nil

          until main_view || same_video_ids.blank?
            main_view = view.class.find_by(id: same_video_ids.shift)
          end

          duration, watched, viewed_at, watched_at, last_viewed_at =
            view.values_from_sidekiq(
              duration,
              watched,
              viewed_at,
              watched_at,
              last_viewed_at
            )

          view.class.where(id: same_video_ids).delete_all if same_video_ids.present?

          return main_view &&
            Meeting::Video::TrackJob.
              set(wait_until: 2.minutes.from_now + (rand * 100)).
              perform_later(main_view, duration, viewed_at, watched, watched_at, last_viewed_at)
        end

        watched = !view.watched && !!watched
        duration = [view.duration.to_i, duration.to_i].max
        athlete_user = (view.athlete_id && view.athlete&.user) || view.user.related_athlete
        athlete_id = view.athlete_id || athlete_user&.category_id

        unless !athlete_user || athlete_user.interest.contactable
          athlete_user.respond_after_uncontactable "Watched Video - #{view.category_title}"
          athlete_user.update(interest_id: Interest::Curious) if athlete_user.interest_id.in? [ Interest::Unknown.id, Interest::NoRespond.id ]
        end

        params = {
          last_viewed_at: last_viewed_at.presence || Time.zone.now
        }

        if watched
          params[:last_viewed_at] = last_viewed_at
          params[:watched] = true

          params[:first_watched_at] =
            watched_at.presence ||
            Time.zone.now

          if duration < 1
            duration = mtg.duration.to_i
          end
        end

        if duration != view.duration.to_i
          params[:last_viewed_at] = last_viewed_at
          params[:duration] = duration

          if !view.first_viewed.presence
            params[:first_viewed_at] =
              viewed_at.presence ||
              watched_at.presence ||
              Time.zone.now
          end
        end

        if view.athlete_id != athlete_id
          params[:athlete_id] = athlete_id
        end

        view.update!(params)
      end
    end
  end
end
