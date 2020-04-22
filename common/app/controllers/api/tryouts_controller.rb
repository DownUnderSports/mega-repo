# encoding: utf-8
# frozen_string_literal: true

module API
  class TryoutsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      return not_authorized("CANNOT REQUEST INFO FOR PREVIOUS YEAR(S)") unless is_active_year?

      successful, errors = nil

      begin
        @params = whitelisted_tryout_params.to_h.deep_symbolize_keys
        raise "Valid School and Sport Information is required" unless valid_school_info
        raise "Valid Athlete Information is required" unless valid_athlete_info
        # raise "Valid Parent/Guardian Information is required" unless valid_guardian_info

        InfokitMailer.
          with(**@params, query: params[:query].to_unsafe_h).
          new_tryout.
          deliver_later(queue: :staff_mailer)
        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    private
      def render_success
        render json: {
          success: true
        }, status: 200
      end

      def valid_athlete_info
        return false unless @params[:athlete].present?

        @params[:athlete][:first].present? &&
        @params[:athlete][:last].present? &&
        (@params[:athlete][:email].to_s =~ /^[^@]+@[^@]+\.[^@.]+$/) &&
        (@params[:athlete][:phone].to_s =~ /[0-9]+/)
      end

      # def valid_athlete_info
      #   return false unless @params[:athlete].present?
      #
      #   @params[:athlete][:first].present? &&
      #   @params[:athlete][:last].present?
      # end

      # def valid_guardian_info
      #   return false unless @params[:guardian].present?
      #
      #   @params[:guardian][:relationship].present? &&
      #   @params[:guardian][:first].present? &&
      #   @params[:guardian][:last].present? &&
      #   (@params[:guardian][:email].to_s =~ /^[^@]+@[^@]+\.[^@.]+$/) &&
      #   (@params[:guardian][:phone].to_s =~ /[0-9]+/)
      # end

      def valid_school_info
        return false unless @params[:athlete].present?

        @params[:athlete][:grad].present? &&
        @params[:athlete][:stats].present? &&
        @params[:athlete][:school_name].present? &&
        @params[:athlete][:school_city].present? &&
        (@params[:athlete][:school_state_abbr] = State.find_by(id: @params[:athlete][:school_state_id])&.abbr) &&
        (@params[:athlete][:sport_abbr] = Sport.find_by(id: @params[:athlete][:sport_id])&.abbr_gender)
      end

      def whitelisted_tryout_params
        params.require(:tryout).permit(
          :type,
          athlete: [
            :first,
            :middle,
            :last,
            :suffix,
            :gender,
            :email,
            :phone,
            :grad,
            :stats,
            :school_name,
            :school_city,
            :school_state_id,
            :sport_id,
          ],
          guardian: [
            :relationship,
            :title,
            :first,
            :middle,
            :last,
            :suffix,
            :email,
            :phone,
          ],
          nominator: [
            :relationship,
            :first,
            :last,
            :email,
            :phone,
          ],
          address: [
            :is_foreign,
            :street,
            :street_2,
            :street_3,
            :city,
            :state_id,
            :province,
            :zip,
            :country,
          ],
        )
      end
  end
end
