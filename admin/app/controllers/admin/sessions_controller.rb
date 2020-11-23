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

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
