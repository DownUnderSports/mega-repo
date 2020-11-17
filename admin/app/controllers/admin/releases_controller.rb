# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ReleasesController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          releases = authorize User::GeneralRelease.joins(:user).includes(:user).merge(User.order(dus_id: :asc))

          if Boolean.parse(params[:force]) || stale?(releases)
            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :version, last_update
              deflator.stream true, :releases, '['

              i = 0
              releases.map do |release|
                deflator.stream (i += 1) > 1, nil, release.as_json
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
        end
      end
    end

    def create
      successful, errors, rel = nil

      begin
        user = User[params[:id]]
        raise "User not found" unless user

        user.create_general_release! whitelisted_release_params
        successful = true
      rescue
        successful = false
        puts errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def update
      successful, errors, rel = nil

      begin
        release = User::GeneralRelease.find_by(id: params[:id])
        raise "Release not found" unless release

        release.update!(whitelisted_release_params)
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
          return nil unless User::GeneralRelease.count > 0

          User::GeneralRelease.
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

      def whitelisted_release_params
        params.require(:release).permit(:release_form, :signed, :allow_contact, :net_refundable, :notes)
      end
  end
end
