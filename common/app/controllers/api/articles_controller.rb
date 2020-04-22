# encoding: utf-8
# frozen_string_literal: true

module API
  class ArticlesController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      return render json: fetch('https://legacy.downundersports.com/api/v1/media'), status: 200
    rescue
      p $!.message
      render json: {articles: []}, status: 422
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
