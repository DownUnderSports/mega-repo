# encoding: utf-8
# frozen_string_literal: true

module Admin
  class TravelGiveawaysController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      expires_now

      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          terms = ThankYouTicket::Terms.latest
          if stale? terms, last_modified: terms.created_at
            return render json: { terms: terms }
          end
        end
      end
    end

    def create
      successful, errors, rel = nil

      begin
        params[:terms][:edited_by_id] = current_user.id
        ThankYouTicket::Terms.create! whitelisted_terms_params unless equal?
        successful = true
      rescue
        successful = false
        puts errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    def equal?
      latest = ThankYouTicket::Terms.latest
      whitelisted_terms_params[:body] == latest&.body
    end

    def whitelisted_terms_params
      @whitelisted_terms_params ||= params.require(:terms).permit(:edited_by_id, :body)
    end
  end
end
