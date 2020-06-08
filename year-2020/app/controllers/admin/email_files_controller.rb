# encoding: utf-8
# frozen_string_literal: true

module Admin
  class EmailFilesController < ::Admin::ApplicationController
    # == Modules ============================================================
    include Uploadable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      raise "No file submitted" unless object_path = params[:object_path]
      file_name = File.basename(params[:file_name].presence || object_path)

      response.headers["Expires"] = 365.days.from_now.httpdate
      response.headers["Cache-Control"] = "private, max-age=#{365.days.to_i}"
      response.headers["Content-Type"] = Rack::Mime.mime_type(File.extname(file_name))
      response.headers["Content-Disposition"] = "attachment; filename=\"#{file_name}\""
      expires_in 365.days, public: false, must_revalidate: true
      self.response_body = Enumerator.new do |y|
        object = s3_bucket.object(object_path)

        chunk_size = 5.megabytes
        offset = 0

        while offset < object.content_length
          y << object.get(range: "bytes=#{offset}-#{offset + chunk_size - 1}").body.read.force_encoding(Encoding::BINARY)
          offset += chunk_size
        end
        object.delete if Boolean.parse(params[:should_delete])
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
  end
end
