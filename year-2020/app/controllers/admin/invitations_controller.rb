# encoding: utf-8
# frozen_string_literal: true

module Admin
  class InvitationsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'internal'

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      @submitted = request.post?
      @row = Invite::Parser.
        new(user.mailings.build).
        override(overrides)
    end

    def infokit
      @submitted = request.post?
      @row = Mailing::Infokit.
        new(user.mailings.build).
        override(ik_overrides)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def user
        test_user ||
        User.athletes.contactable.take
      end

      def overrides
        @invitable = Boolean.parse(invite_params[:invitable])
        @certifiable = Boolean.parse(invite_params[:certifiable])
        @sport_id = invite_params[:sport_id].presence || test_user.team.sport_id

        @overrides = {
          "sport" => Sport[@sport_id],
          "invite_rule" => Invite::Rule.where(certifiable: @certifiable, invitable: @invitable).take
        }

        @overrides
      end

      def invite_params
        @invite_params ||= params.require(:invitation).permit(
          :certifiable,
          :invitable,
          :sport_id
        )
      rescue
        @invite_params = {}
      end

      def ik_overrides
        @is_home = Boolean.parse(infokit_params[:is_home])
        @sport_id = infokit_params[:sport_id].presence || test_user.team.sport_id
        sport = Sport[@sport_id]

        @overrides = {
          "sport" => sport,
          "invited_athlete_sport" => sport,
          "is_home" => @is_home
        }

        @overrides
      end

      def infokit_params
        @infokit_params ||= params.require(:infokit).permit(
          :is_home,
          :sport_id
        )
      rescue
        @infokit_params = {}
      end

  end
end
