# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class BaseController < ::Aus::ApplicationController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y, 'concat')

          deflator.stream false, nil, { total: records.size, deleted: deleted_records&.size }

          deflator.stream false, nil, "--JSON--SPLIT--ARRAY--"

          i = 0
          records.each do |r|
            deflator.stream false, nil, r.to_json
          end

          if deleted_records.present?
            deflator.stream false, nil, "--JSON--SPLIT--ARRAY--"

            deleted_records.each do |d|
              deflator.stream false, nil, d.to_json
            end
          end

          deflator.close
        end
      end

      # == Cleanup ============================================================

      private
        def deleted_records
          @deleted_records ||= get_deleted_records
        rescue
          nil
        end

        def get_records
          raise "Not Implemented"
        end

        def get_deleted_records
          raise "Not Implemented"
        end

        def records
          @records ||= get_records
        end

        def records=(value)
          @records = value
        end

        def records_last_updated_at
          @records_last_updated_at ||=
            (
              params[:last_updated].presence \
              && Time.zone.parse(params[:last_updated])
            )
        end
    end
  end
end
