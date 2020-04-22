# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

# User::RefundRequest description
class User < ApplicationRecord
  class RefundRequest < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_commit :send_notification, on: :create

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def url
      "#{Rails.env.development? ? "http://lvh.me:3000" : "https://admin.downundersports.com"}/admin/accounting/refund_requests/#{self.id}"
    end

    def send_notification
      StatementMailer.
        with(id: self.id).
        over_payment_request.
        deliver_later
    end

  end
end
