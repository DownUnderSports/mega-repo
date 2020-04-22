# encoding: utf-8
# frozen_string_literal: true

module API
  class SportsController < API::ApplicationController
    before_action :set_sport, only: [:show]

    def index
      if stale? last_modified: sports_last_modified
        @sports = Sport.order(:abbr, :abbr_gender).select(:id, :abbr, :full, :abbr_gender, :full_gender)

        render json: @sports
      end
    end

    def show
      authorize @sport
      if stale? last_modified: @sport.info&.updated_at || sports_last_modified
        render json: @sport.to_json(include: {
          info: {
            only: [
              :title,
              :tournament,
              :first_year,
              :departing_dates,
              :team_count,
              :team_size,
              :description,
              :bullet_points_array,
              :programs_array,
              :background_image,
              :additional
            ]
          }
        })
      end
    end

    private
      # Use callbacks to share common setup or constraints between actions.
      def set_sport
        if params[:id].to_s =~ /[0-9]+/
          @sport = Sport.includes(:info).find_by(id: params[:id])
        else
          @sport = Sport.includes(:info).where(abbr_gender: params[:id].upcase).
                   or(Sport.includes(:info).where(full_gender: params[:id].titleize)).
                   limit(1).first
        end
      end

      def sports_last_modified
        File.mtime(Rails.root.join("tmp/sport_last_modified"))
      rescue
        FileUtils.touch Rails.root.join("tmp/sport_last_modified"), mtime: Sport::LoggedAction.maximum(:ACTION_TSTAMP_TX)
        sports_last_modified
      end
  end
end
