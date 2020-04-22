# encoding: utf-8
# frozen_string_literal: true

module Admin
  class VideoViewsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index, :totals ]

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def totals
      athletes = Meeting::Video::View.where(users: { category_type: :athletes })
      coaches = Meeting::Video::View.where(users: { category_type: :coaches })

      totals = {
        athletes: {
          contactable: athletes.joins(user: :interest).where(interests: { contactable: true }).count,
          uncontactable: athletes.joins(user: :interest).where.not(interests: { contactable: true }).count,
          traveling: athletes.joins(user: :traveler).where(travelers: { cancel_date: nil }).count,
          cancels: athletes.joins(user: :traveler).where.not(travelers: { cancel_date: nil }).count,
        },
        coaches: {
          contactable: coaches.joins(user: :interest).where(interests: { contactable: true }).count,
          uncontactable: coaches.joins(user: :interest).where.not(interests: { contactable: true }).count,
          traveling: coaches.joins(user: :traveler).where(travelers: { cancel_date: nil }).count,
          cancels: coaches.joins(user: :traveler).where.not(travelers: { cancel_date: nil }).count,
        }
      }

      respond_to do |format|
        format.json do
          return render json: totals
        end
        format.csv do
          authorize Meeting::Video::View

          SendCSVJob.perform_later(
            current_user&.id,
            "admin/video_views/totals.csv.csvrb",
            "viewed_videos_totals",
            "Viewed Videos - Totals",
            "Viewed Videos Summary Totals as of #{Date.today.to_s}",
            { totals: totals }
          )

          return render_success(current_user&.email || 'it@downundersports.com')
        end
      end
    end

    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          lookup_user
          views = authorize @found_user.
            video_views.
            joins(:video).
            select('meeting_video_views.*', 'meeting_videos.link', 'meeting_videos.category').
            order('meeting_videos.category', :video_id)

          if stale? etag: views, last_modified: views.try(:maximum, 'GREATEST(meeting_videos.updated_at, meeting_video_views.updated_at)')
            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :version, last_update
              deflator.stream true, :views, '['

              i = 0
              views.map do |view|
                deflator.stream (i += 1) > 1, nil, {
                  id: view.id,
                  video_id: view.video_id,
                  user_id: view.user_id,
                  link: view.link,
                  category: Meeting::Category.titleize(view.category),
                  duration: view.duration,
                  watched: !!view.watched,
                  first_viewed: view.first_viewed&.strftime('%Y-%m-%d @ %R'),
                  last_viewed: view.last_viewed&.strftime('%Y-%m-%d @ %R'),
                  first_watched: view.first_watched&.strftime('%Y-%m-%d @ %R'),
                  created_at: view.created_at&.strftime('%Y-%m-%d @ %R'),
                  updated_at: view.updated_at&.strftime('%Y-%m-%d @ %R'),
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
        end
        format.csv do
          authorize Meeting::Video::View

          SendCSVJob.perform_later(
            current_user&.id,
            "admin/video_views/index.csv.csvrb",
            "viewed_videos",
            "Viewed Videos - #{Date.today.to_s}",
            "Viewed Videos as of #{Date.today.to_s}"
          )

          return render_success(current_user&.email || 'it@downundersports.com')

          # render  csv: "index",
          #         filename: "viewed_videos",
          #         with_time: true
        end
      end
    end

    def update
      save_view @found_user.video_views.find_by(id: params[:id])
    end

    def create
      save_view @found_user.video_views, 'create!'.to_sym
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def last_update
        begin
          return nil unless @found_user.video_views.count > 0

          @found_user.video_views.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end

      def save_view(view, method = 'update!'.to_sym)
        successful, errors, rel = nil

        begin
          if params[:id].present? && whitelisted_view_params[:video_id].blank?
            Meeting::Video::View.
            where(
              video_id: view.video_id,
              user_id: [ @found_user.id, *@found_user.relations.map(&:related_user_id) ]
            ).each {|reg| reg.destroy! }
          else
            if params[:view][:duration].blank?
              params[:view][:watched] = false
              params[:view][:duration] = '00:00:00'
            end
            if method.to_s =~ /create/
              view = view.__send__(method, whitelisted_view_params)
              @found_user.related_users.each do |u|
                view = view.dup
                view.user = u
                view.save!
              end
            else
              Meeting::Video::View.
              where(
                video_id: view.video_id,
                user_id: [ @found_user.id, *@found_user.relations.map(&:related_user_id) ]
              ).
              each do |reg|
                reg.__send__(method, whitelisted_view_params)
              end
            end
          end

          successful = true
        rescue
          successful = false
          puts errors = $!.message
          puts $!.backtrace
        end

        return successful ? render_success : not_authorized(errors, 422)
      end

      def whitelisted_view_params
        params.require(:view).permit(:id, :video_id, :watched, :duration)
      end

  end
end
