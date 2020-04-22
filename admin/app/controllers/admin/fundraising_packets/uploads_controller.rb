# encoding: utf-8
# frozen_string_literal: true

module Admin
  module FundraisingPackets
    class UploadsController < ::Admin::ApplicationController
      layout 'internal'

      include Uploadable

      def show
        @file_stats = JSON.parse(params[:file_stats]) rescue nil

        respond_to do |format|
          format.html
          format.csv do
            csv_data =
              FileValidation.to_csv(:fundraising_packet_fields) +
              CSV.generate_line([ 'AAA-AAA', '2019-10-31 7 PM', '2019-10-31' ])

            send_data csv_data, filename: "mark-fr-packet-headers.csv"
          end
        end
      end

      def create
        @file_stats = csv_upload(whitelisted_upload_params[:file])

        open_tempfile do |file|
          file.write @file_stats[:body].force_encoding("UTF-8")
          file.flush
          file.rewind

          FundraisingPacket::Processor.parse_file(file, path: @file_stats[:name], skip_invalid: true)
        end

        return redirect_to admin_fundraising_packets_upload_path(file_stats: JSON[@file_stats.except(:body)])
      end
    end
  end
end
