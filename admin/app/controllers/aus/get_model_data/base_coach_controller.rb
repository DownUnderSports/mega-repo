# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class BaseCoachController < ::Aus::GetModelData::BaseController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================

      private
        def user_has_valid_access?
          super || (
            (
              BetterRecord::Current.user = \
                User[request.headers['DUSID']]
            ) \
            && (
              current_user.is_staff? \
              || (
                current_user.is_coach? \
                && current_user.traveler&.active?
              )
            )
          )
        end
    end
  end
end
