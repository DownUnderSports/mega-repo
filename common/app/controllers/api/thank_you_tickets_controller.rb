# encoding: utf-8
# frozen_string_literal: true

module API
  class ThankYouTicketsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      terms = ThankYouTicket::Terms.latest

      if stale? terms, last_modified: terms.created_at
        return render json: { terms: terms }
      end
    end

    def show
      terms = ThankYouTicket::Terms.find_by(id: params[:id]) || ThankYouTicket::Terms.latest

      if stale? terms, last_modified: terms.created_at
        return render json: { terms: terms }
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
  end
end
