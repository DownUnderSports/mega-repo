# encoding: utf-8
# frozen_string_literal: true

module Travel
  class ApplicationController < ::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================

    # == Cleanup ============================================================
    def app_base
      'travel'
    end

    def fallback_index_html
      response.headers['Cache-Control'] = 'public'
      response.headers['Service-Worker-Allowed'] = '/travel'
      return super
    end

    def serve_asset
      response.headers['Service-Worker-Allowed'] = '/travel'

      response.headers['Vary'] = 'User-Agent'

      return super
    end

    def valid_user_for_path
      user = User[params[:dus_id]]

      return render json: {
        errors: [ "Active Traveler Not Found" ]
      }, status: 500 unless user&.traveler&.active?

      set_current_user_cookies user

      return render json: {
        token: encrypt_token,
        requesting_device_id: requesting_device_id,
        current_user_session_data: current_user_session_data
      }, status: 200
    end

  end
end
