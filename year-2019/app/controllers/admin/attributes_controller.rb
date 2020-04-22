# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AttributesController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      model = params[:id].singularize.classify.constantize
      return render json: model.attribute_types_arr(true), status: 200
    rescue
      return render json: {error: $!.message}, status: 500
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
