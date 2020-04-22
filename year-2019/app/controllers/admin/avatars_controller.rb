# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AvatarsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index ]

    # == Actions ============================================================
    def show
      redirect_to @found_user.avatar, status: 303
    end

    def update
      return not_authorized("CANNOT ADD/REMOVE/MODIFY PHOTOS IN PREVIOUS YEARS", 422)
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
