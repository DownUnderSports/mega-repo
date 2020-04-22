# encoding: utf-8
# frozen_string_literal: true

module Admin
  class TransferExpectationsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def show
      expectation = authorize @found_user.get_or_create_transfer_expectation

      if Boolean.parse(params[:force]) || stale?(expectation)
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y)

          deflator.stream false, :version, last_update
          deflator.stream true, :transfer_expectation, expectation.as_json.null_to_str

          deflator.close
        end
      end
    end

    def update
      expectation = authorize @found_user.get_or_create_transfer_expectation

      successful, errors= nil

      begin
        expectation.update! whitelisted_expectation_params.merge(staff_user_id: current_user&.id)
        successful = true
      rescue
        successful = false
        puts errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def last_update
        begin
          return nil unless @found_user&.transfer_expectation
          @found_user.
            transfer_expectation.
            updated_at.
            utc.
            iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:id])
        end
      end

      def whitelisted_expectation_params
        params.
          require(:transfer_expectation).
          permit(:difficulty, :status, :can_transfer, :can_compete, :notes)
      end
  end
end
