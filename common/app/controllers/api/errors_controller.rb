# encoding: utf-8
# frozen_string_literal: true

module API
  class ErrorsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      errors = params.to_unsafe_h.deep_symbolize_keys.except(:controller, :action)
      ErrorMailer.with(server_time: Time.zone.now.to_s, **errors).log_error.deliver_later(queue: 'error_mailer') unless Rails.env.development? || (errors[:additional].blank? || (errors[:additional][:message].to_s !~ /NS_ERROR/))
      head :ok
    end

    def load_errors
      ErrorMailer.with(server_time: Time.zone.now.to_s, **params.to_unsafe_h.deep_symbolize_keys).load_error.deliver_now!
      # deliver_later(queue: 'error_mailer')
      head :ok
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
