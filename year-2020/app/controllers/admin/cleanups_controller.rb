# encoding: utf-8
# frozen_string_literal: true

module Admin
  class CleanupsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_athlete_sport

    # == Actions ============================================================
    def show
      return render json: {
        errors: [ "Stats Not Found" ]
      }, status: 500 unless @athletes_sport

      return render json: {
        athlete_id: @athletes_sport.athlete_id,
        attributes: @athletes_sport.as_json,
        gender: @athletes_sport.athlete.user.gender,
        grad: @athletes_sport.athlete.grad,
        sport: @athletes_sport.sport.abbr_gender,
        stats: @athletes_sport.stats,
        transferability: @athletes_sport.transferability,
        user_id: @athletes_sport.athlete.user.id
      }.null_to_str, status: 200
    end

    def update
      successful, errors, rel = nil

      begin
        @athletes_sport.update!(transferability_params)
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def lookup_athlete_sport
        if !request.format.html?
          @athletes_sport = authorize AthletesSport.find_by(id: params[:id])
        end
      end

      def transferability_params
        params.
          require(:athletes_sport).
          permit(:transferability)
      end
  end
end
