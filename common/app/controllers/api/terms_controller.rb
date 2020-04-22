# encoding: utf-8
# frozen_string_literal: true

module API
  class TermsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      terms = Payment::Terms.latest

      if stale? terms, last_modified: terms.created_at
        return render json: { terms: terms }
      end
    end

    def show
      terms = Payment::Terms.find_by(id: params[:id]) || Payment::Terms.latest

      if stale? terms, last_modified: terms.created_at
        return render json: { terms: terms }
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
  end
end
