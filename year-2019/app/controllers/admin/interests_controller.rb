# encoding: utf-8
# frozen_string_literal: true

module Admin
  class InterestsController < ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      render json: Interest.order(:id) if stale? last_modified: interests_last_modified
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    def interests_last_modified
      File.mtime(Rails.root.join("tmp/interest_last_modified"))
    rescue
      FileUtils.touch Rails.root.join("tmp/interest_last_modified"), mtime: Time.now
      interests_last_modified
    end
  end
end
