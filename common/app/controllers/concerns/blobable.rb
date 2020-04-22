# encoding: utf-8
# frozen_string_literal: true

module Blobable
  extend ActiveSupport::Concern

  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================

  # == Actions ============================================================

  # == Cleanup ============================================================

  # == Utilities ==========================================================

  private
    def create_blob
      blob = ActiveStorage::Blob.create_before_direct_upload!(blob_args)
      render json: direct_upload_json(blob)
    end

    def blob_args
      params.require(:blob).
        permit(
          :filename,
          :byte_size,
          :checksum,
          :content_type,
          :metadata
        ).to_h.symbolize_keys
    end

    def direct_upload_json(blob)
      blob.
        as_json(methods: :signed_id).
        merge(direct_upload: {
          url: blob.service_url_for_direct_upload,
          headers: blob.service_headers_for_direct_upload
        })
    end
end
