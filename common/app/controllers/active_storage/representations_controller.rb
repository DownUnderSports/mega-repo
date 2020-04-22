# encoding: UTF-8
# frozen_string_literal: true

require 'active_storage'

module ActiveStorage
  class RepresentationsController < BaseController
    include ActiveStorage::SetBlob

    def show
      representation = @blob.representation(params[:variation_key]).processed
      if stale? etag: "#{@blob.try(:created_at)}#{representation.key}", last_modified: @blob.try(:created_at)
        expires_now
        variant = representation
        send_data @blob.service.download(variant.key),
          type: @blob.content_type || DEFAULT_SEND_FILE_TYPE,
          disposition: 'inline'
      end
    end
  end
end
