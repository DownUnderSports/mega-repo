# encoding: utf-8
# frozen_string_literal: true

module API
  class PrivacyPoliciesController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      privacy_policy = PrivacyPolicy.latest

      if stale? privacy_policy, last_modified: privacy_policy.created_at
        return render json: { privacy_policy: privacy_policy }
      end
    end

    def show
      privacy_policy = PrivacyPolicy.find_by(id: params[:id]) || PrivacyPolicy.latest

      if stale? privacy_policy, last_modified: privacy_policy.created_at
        return render json: { privacy_policy: privacy_policy }
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
  end
end
