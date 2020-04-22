# encoding: utf-8
# frozen_string_literal: true

module API
  class DirectUploadsController < API::ApplicationController
    # == Modules ============================================================
    include Blobable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action do
      ActiveStorage::Current.host = request.base_url
    end

    # == Actions ============================================================
    def create
      authorize ActiveStorage::Blob
      create_blob
    end

    def assignment_of_benefits
      authorize User.find_by_dus_id_hash(params[:id]), :assignment_of_benefits_blob?
      create_blob
    end

    def passport
      authorize User.find_by_dus_id_hash(params[:id]), :passport_blob?
      create_blob
    end

    def legal_form
      authorize User.find_by_dus_id_hash(params[:id]), :legal_form_blob?
      create_blob
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
