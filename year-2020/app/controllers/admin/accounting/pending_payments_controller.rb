# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class PendingPaymentsController < ::Admin::ApplicationController
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

            base_payments =
              filter ?
                payments_list.where(filter, options.deep_symbolize_keys) :
                payments_list

            payments = base_payments.
              order(*get_sort_params, :created_at, :id).
              offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_payments.count('1')
              deflator.stream true, index_key, '['

              i = 0
              payments.each do |payment|
                deflator.stream (i += 1) > 1, nil, {
                  id:             payment.id,
                  transaction_id: payment.transaction_id,
                  gateway_type:   payment.gateway_type,
                  created_at:     payment.created_at,
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
            raise "Not Found" unless payment = get_payment

            return render json: payment.attributes.merge(link: payment.user.admin_url)
          end
        end
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def update
        raise "Not Found" unless payment = get_payment

        payment.accept!

        return render json: { message: 'ok' }, status: 200
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def destroy
        raise "Not Found" unless payment = get_payment

        payment.void!

        return render json: { message: 'ok' }, status: 200
      rescue
        return not_authorized([ $!.message ], 422)
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def index_key
          :pending_payments
        end

        def allowed_keys
          @allowed_keys ||= [
            :created_at,
            :gateway_type,
            :transaction_id
          ].freeze
        end

        def get_payment
          authorize Payment.find(params[:id]), :pending?
        end

        def is_proxy?
          super && current_user.is_staff? && current_user.staff.check(:finances)
        end

        def payments_list
          Payment.pending
        end

        def whitelisted_filter_params
          params.permit(allowed_keys)
        end
    end
  end
end
