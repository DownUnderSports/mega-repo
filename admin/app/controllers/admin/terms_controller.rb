# encoding: utf-8
# frozen_string_literal: true

module Admin
  class TermsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      expires_now

      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          terms = Payment::Terms.latest
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
        Payment::Terms.create! whitelisted_terms_params unless equal?
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
      latest = Payment::Terms.latest
      whitelisted_terms_params[:body] == latest.body &&
      whitelisted_terms_params[:minor_signed_terms_link] == latest.minor_signed_terms_link &&
      whitelisted_terms_params[:adult_signed_terms_link] == latest.adult_signed_terms_link
    end

    def whitelisted_terms_params
      @whitelisted_terms_params ||= params.require(:terms).permit(:edited_by_id, :body, :minor_signed_terms_link, :adult_signed_terms_link)
    end
  end
end
