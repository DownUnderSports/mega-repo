# encoding: utf-8
# frozen_string_literal: true

module API
  class InfokitsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def valid
      result = 204
      begin
        authorize user, policy_class: InfokitPolicy
      rescue not_authorized_error
        result = 410
      end
      return head result
    end

    def create
      return not_authorized("CANNOT REQUEST INFO FOR PREVIOUS YEAR(S)") unless is_active_year?

      authorize user, policy_class: InfokitPolicy

      successful, errors = nil

      begin
        @user ||= User.new(whitelisted_infokit_params[:user])
        successful, errors = @user.infokit_request(whitelisted_infokit_params.to_h.deep_symbolize_keys)
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace

        begin
          ErrorMailer.
            with(
              **params.to_h.deep_symbolize_keys,
              error: $!.message,
              stack: $!.backtrace,
              user_id: @user.id,
              server_time: Time.zone.now.to_s
            ).invalid_infokit_request.deliver_later if @user && @user.id.present?
        rescue
          puts "Error Sending Bad Infokit"
          puts $!.backtrace
        end
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    private
      def not_authorized(err, status = 403)
        err = 'Infokit previously requested' unless err.present? && !err.is_a?(not_authorized_error)

        super(err, status)
      end

      def render_success
        render json: {
          success: true
        }, status: 200
      end

      def user
        @user ||= User.get(params[:id] || whitelisted_infokit_params[:dus_id])
      end

      def whitelisted_infokit_params
        params.require(:infokit).permit(
          :force,
          :dus_id,
          :type,
          user: [
            :first,
            :middle,
            :last,
            :suffix,
            :email,
            :phone,
            :new_password,
            :new_password_confirmation,
            address_attributes: [
              :is_foreign,
              :street,
              :street_2,
              :street_3,
              :city,
              :state_id,
              :province,
              :zip,
              :country,
            ]
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
            :gender,
            :new_password,
            :new_password_confirmation,
            address_attributes: [
              :is_foreign,
              :street,
              :street_2,
              :street_3,
              :city,
              :state_id,
              :province,
              :zip,
              :country,
            ]
          ],
        )
      end
  end
end
