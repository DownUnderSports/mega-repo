# encoding: utf-8
# frozen_string_literal: true

module Aus
  class ApplicationController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    skip_before_action :verify_user_access, only: [ :valid_user_for_path ]

    # == Actions ============================================================

    # == Cleanup ============================================================
    def app_base
      'aus'
    end

    def s3_asset_path
      "#{super}/service_worker"
    end

    def fallback_index_html
      response.headers['Cache-Control'] = 'public'
      response.headers['Service-Worker-Allowed'] = '/aus'
      return super
    end

    def serve_asset
      response.headers['Service-Worker-Allowed'] = '/aus'

      response.headers['Vary'] = 'User-Agent'

      return super
    end

    def valid_user_for_path
      user = User[params[:dus_id]]

      return render json: {
        errors: [ "User Not Found" ]
      }, status: 500 unless user

      return render json: {
        errors: [ "User Not Authorized" ]
      }, status: 410 unless valid_path_for_user(user, params[:path].presence)

      set_current_user_cookies(user)

      return render json: {
        id: (current_user.dus_id rescue nil),
        token: encrypt_token,
        requesting_device_id: requesting_device_id,
        current_user_session_data: current_user_session_data
      }, status: 200
    end

    private
      def valid_path_for_user(user, path_to_check)
        return false unless user && path_to_check.present?

        case user.category_type
        when /coach/i
          user.traveler&.active? && /aus\/(airports|check)/ =~ path_to_check
        when /staff/i
          !user.certificate? || (/aus\/(airports|check)/ =~ path_to_check)
        else
          false
        end
      rescue
        false
      end

  end
end
