# encoding: utf-8
# frozen_string_literal: true

module Admin
  class RequestsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      requests = authorize Traveler::Request.order(:created_at).where(traveler: @found_user&.traveler)

      if Boolean.parse(params[:force]) || stale?(requests)
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y)

          deflator.stream false, :version, last_update
          deflator.stream true, :requests, '['

          i = 0
          requests.map do |r|
            deflator.stream (i += 1) > 1, nil, {
              id: r.id,
              traveler_id: r.traveler_id,
              category: r.category,
              details: r.details,
            }
          end

          deflator.stream false, nil, ']'

          deflator.close
        end
      end
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def last_update
        begin
          return nil unless @found_user&.traveler&.requests.count&.>(0)
          @found_user.
            traveler.
            requests.
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end
  end
end
