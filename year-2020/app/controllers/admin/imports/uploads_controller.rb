# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Imports
    class UploadsController < ::Admin::ApplicationController
      layout 'internal'

      include Uploadable

      def show
        @file_stats = JSON.parse(params[:file_stats]) rescue nil

        respond_to do |format|
          format.html
          format.csv { send_data FileValidation.to_csv(:import_fields), filename: "import-athlete-headers.csv" }
        end
      end

      def create
        @file_stats = csv_upload(whitelisted_upload_params[:file])

        open_tempfile do |file|
          file.write @file_stats[:body].force_encoding("UTF-8")
          file.flush
          file.rewind

          Import::Processor.parse_file(file, path: @file_stats[:name], skip_invalid: true, current_user_id: (current_user || check_user)&.id)
        end

        return redirect_to admin_imports_upload_path(file_stats: JSON[@file_stats.except(:body)])
      end
    end
  end
end
