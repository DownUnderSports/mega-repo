# encoding: utf-8
# frozen_string_literal: true

module API
  class VideosController < API::ApplicationController
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      @videos = Meeting::Video.order(:category, :id)

      if stale? @videos
        return render json: {
          videos: (
            @videos.map do |video|
              {
                id: video.id,
                category: Meeting::Category.titleize(video.category),
                link: video.link,
                duration: video.duration,
                sent: video.sent,
                viewed: video.viewed,
              }
            end
          ),
          version: last_update
        }
      end
    end

    def show
      v = Meeting::Video.order(id: :desc).find_by(category: params[:id].to_s.upcase[0])
      render json: {
        has_offers: !!v&.offer.present?,
        has_tracking: true,
        tracking_url: "/api/videos/#{params[:id].to_s.upcase[0]}/:user_id",
        url: v&.link,
      }
    end

    def track
      @found_user = User.visible.get(params[:tracking_id])

      mtgs = mtg = nil
      if @found_user && (
        mtgs =
          Meeting::Video.
            order(id: :desc).
            where(
              category: params[:id].to_s.upcase[0],
              link: params[:url]
            )
      ).exists?
        video_view =
          @found_user.video_views.find_by(video_id: mtgs.pluck(:id)) ||
          @found_user.video_views.create!(video_id: mtgs.limit(1).take.id)

        unless @found_user.responded_at? || (params[:played_seconds].to_i < 1)
          @found_user.update!(responded_at: video_view.created_at)
        end

        duration, watched, deadline, two_weeks = video_view.track(
          duration: params[:played_seconds].to_i,
          played: params[:played].to_d
        )

        return render json: {
          max_watched: duration.to_i,
          watched: !!watched,
          deadline: watched ? deadline&.to_s : nil,
          two_weeks: watched ? two_weeks : nil,
          traveler: !!@found_user.traveler
        }, status: 200
      end
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: {}, status: 500
    end

    private
      def last_update
        begin
          Meeting::Video.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end
  end
end
