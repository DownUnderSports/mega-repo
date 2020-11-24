# encoding: utf-8
# frozen_string_literal: true

module Admin
  class SessionsController < ::Admin::ApplicationController
    # == Modules ============================================================
    include BetterRecord::Sessionable

    layout 'internal'

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    skip_before_action :verify_user_access

    # == Actions ============================================================
    def index
      return render json: session, status: 200
    end

    def create
      if(user = session_class.__send__(session_authenticate_method, params))
        self.current_token = create_jwt(user)
        set_user(user)
      end
      return respond_to_login
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def respond_to_login
        respond_to do |format|
          format.json do
            return render json: {
              token: encrypt_token,
              requesting_device_id: requesting_device_id,
              current_user_session_data: current_user_session_data,
              id: (current_user.dus_id rescue nil).to_s,
            }, status: 200
          end
          format.html do
            return redirect_to (
              (!use_bearer_token && session.delete(:referrer)) ||
              __send__(after_login_path) ||
              root_path
            )
          end
        end
      end

  end
end
