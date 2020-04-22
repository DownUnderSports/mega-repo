# encoding: utf-8
# frozen_string_literal: true

module API
  class StatesController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      @states = State.order(:abbr, :full).select(:id, :abbr, :full, :conference, :is_foreign)

      if stale? last_modified: states_last_modified
        return render json: @states
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    def states_last_modified
      File.mtime(Rails.root.join("tmp/state_last_modified"))
    rescue
      FileUtils.touch Rails.root.join("tmp/state_last_modified"), mtime: State::LoggedAction.maximum(:ACTION_TSTAMP_TX)
      states_last_modified
    end
  end
end
