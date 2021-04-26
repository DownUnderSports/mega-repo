# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AuthenticationController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :set_allowed_headers
    skip_before_action :verify_user_access

    # == Actions ============================================================
    def index
      return render json: {
        errors: [ "User Not Found" ]
      }, status: 500 unless check_user

      return render json: {
        token: encrypt_token,
        requesting_device_id: requesting_device_id,
        current_user_session_data: current_user_session_data,
        id: (current_user.dus_id rescue nil).to_s,
      }, status: 200
    end

    def preflight
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def set_allowed_headers
        response.set_header "Access-Control-Max-Age", 24.hours.to_i
        response.set_header "Access-Control-Allow-Origin", allow_origin_value
        response.set_header "Access-Control-Allow-Headers", 'Origin, X-Requested-With, Content-Type, Accept, Authorization'
      end

      def user_has_valid_access?
        true
      end

      def verify_user_access
        (
          is_proxy? &&
          current_user
        )
      end

      def is_proxy?
        !!(
          (header_hash[:HTTP_HOST] =~ /(\.|^)downundersports\.com$/i) &&
          (header_hash[:HTTP_X_FORWARDED_BY] == '10.0.0.10:443') &&
          (header_hash[:HTTP_X_FORWARDED_FOR] =~ /(204\.132\.140\.194|74\.92\.245\.66)$/)
        )
      end

      if Rails.env.development?
        def allow_origin_value
          '*'
        end

        def current_token
          @current_token ||= create_jwt(auto_worker, { has_certificate: true })
        end
      else
        def allow_origin_value
          header_hash[:Origin].to_s =~ /downundersports.com$|^downundersports-(admin|\d+)\.herokuapp.com$/ ?
            header_hash[:Origin] :
            'https://admin.downundersports.com'
        end

        def current_token
          @current_token
        end

        def requesting_device_id
          params[:device_id] || SecureRandom.uuid
        end
      end



      # def decrypt_certificate(cert, options = nil)
      #   value, gpg_res = decrypt_gpg_base64(cert)
      #   value&.clean_certificate
      # rescue
      # end

  end
end
