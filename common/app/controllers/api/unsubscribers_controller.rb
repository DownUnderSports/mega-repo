# encoding: utf-8
# frozen_string_literal: true

module API
  class UnsubscribersController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      return head Unsubscriber.find_by(
        value: params[:value].downcase,
        category: params[:category].presence || 'E'
      ) ? 200 : 422
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
