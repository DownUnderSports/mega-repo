# encoding: utf-8
# frozen_string_literal: true

module API
  class PaymentsController < API::ApplicationController
    # == Modules ============================================================
    include Payable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      params[:state_id] = nil
      # return render(create_payment)
      return render(
        json: {
          status: 'failed',
          message: 'Payment Not Allowed',
          errors: [ 'Payment Form Disabled Until Further Notice' ]
        },
        status: 422
      )
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
