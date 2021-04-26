# encoding: utf-8
# frozen_string_literal: true

module API
  class ErrorsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      head :ok
    end

    def load_errors
      # deliver_later(queue: 'error_mailer')
      head :ok
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
