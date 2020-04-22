# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class BillingLookupsController < ::Admin::Accounting::PendingPaymentsController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.any do
            raise "Not Found" unless payment = get_payment

            return render json: payment.billing.merge(link: payment.user.admin_url)
          end
        end
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def update
        return not_authorized([ "Not Allowed" ], 422)
      end

      def destroy
        return not_authorized([ "Not Allowed" ], 422)
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def index_key
          :billing_lookups
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
          Payment.all
        end

        def whitelisted_filter_params
          params.permit(allowed_keys)
        end
    end
  end
end
