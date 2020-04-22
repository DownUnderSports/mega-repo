# encoding: utf-8
# frozen_string_literal: true

module Admin
  class PrivacyPoliciesController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      expires_now

      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          privacy_policy = PrivacyPolicy.latest
          if stale? privacy_policy, last_modified: privacy_policy.created_at
            return render json: { privacy_policy: privacy_policy }
          end
        end
      end
    end

    def create
      successful, errors, rel = nil

      begin
        params[:privacy_policy][:edited_by_id] = current_user.id
        PrivacyPolicy.create! whitelisted_policy_params unless equal?
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
      latest = PrivacyPolicy.latest
      whitelisted_policy_params[:body] == latest.body
    end

    def whitelisted_policy_params
      @whitelisted_policy_params ||=
        params.
          require(:privacy_policy).
          permit(:edited_by_id, :body)
    end
  end
end
