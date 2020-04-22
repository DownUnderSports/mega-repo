# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class TransfersController < Admin::ApplicationController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def create

        if is_transaction_lookup
          raise "User Not Found" unless authorize(User[whitelisted_lookup_params[:user]], :create_transfer?)

          Payment.create_from_lookup **whitelisted_lookup_params
        else
          raise "User Not Found" unless authorize(User[whitelisted_transfer_params[:from]], :create_transfer?)

          Payment.create_transfer **whitelisted_transfer_params
        end

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

        def is_transaction_lookup
          Boolean.parse(params[:transfer][:is_transaction_lookup])
        rescue
          false
        end

        def whitelisted_lookup_params
          params.require(:transfer).permit(
            :user,
            :transaction_id,
          ).to_h.deep_symbolize_keys
        end

        def whitelisted_transfer_params
          params.require(:transfer).permit(
            :amount,
            :from,
            :quantity,
            :to,
            :is_uniform,
            :is_refund,
          ).to_h.deep_symbolize_keys
        end
    end
  end
end
