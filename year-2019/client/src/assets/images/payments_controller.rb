module API
  class PaymentsController < API::ApplicationController
    # == Modules ============================================================
    include Payable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      return create_payment
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    
  end
end
