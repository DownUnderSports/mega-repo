# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class RefundRequestsController < Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            filter, options = filter_records

            base_refund_requests =
              filter ?
                refund_requests_list.where(filter, options.deep_symbolize_keys) :
                refund_requests_list

            refund_requests = base_refund_requests.
              order(*get_sort_params, :dus_id, :id).
              offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_refund_requests.count('1')
              deflator.stream true, :refund_requests, '['

              i = 0
              refund_requests.each do |request|
                deflator.stream (i += 1) > 1, nil, {
                  id:         request.id,
                  created_at: request.created_at,
                  dus_id:     request.dus_id,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
        end
      end

      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.any do
            raise "Not Found" unless refund = authorize(User::RefundRequest.find(params[:id]))

            return render json: JSON.parse(
              decrypt_gpg_base64(refund.value).first.from_b64
            ).merge(link: refund.user.admin_url)
          end
        end
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def destroy
        raise "Not Found" unless refund = authorize(User::RefundRequest.find(params[:id]))

        refund.destroy!

        return render json: { message: 'ok' }, status: 200
      rescue
        return not_authorized([ $!.message ], 422)
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def allowed_keys
          @allowed_keys ||= [
            :created_at,
            :dus_id
          ].freeze
        end

        def is_proxy?
          super && current_user.is_staff? && current_user.staff.check(:finances)
        end

        def refund_requests_list
          User::RefundRequest.
            joins(
              <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                INNER JOIN (
                  SELECT
                    id,
                    dus_id
                  FROM users
                ) users
                  ON users.id = user_refund_requests.user_id
              SQL
            ).
            select(
              "user_refund_requests.*",
              "users.dus_id",
            )
        end

        def whitelisted_filter_params
          params.permit(allowed_keys)
        end
    end
  end
end
