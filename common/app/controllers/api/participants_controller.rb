# encoding: utf-8
# frozen_string_literal: true

module API
  class ParticipantsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      render json: { participants: participants }, status: 200 if stale? last_modified: Participant::Views::Map.last_refresh
    end

    def show
      raise 'state not found' unless state = State[params[:id]]
      @participants = participants.where(state_id: state.id)
      return index
    rescue
      p $!.message
      render json: {
        participants: []
      }, status: 422
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def participants
        @participants ||= Participant::Views::Map.all
      end
  end
end
