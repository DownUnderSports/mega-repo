# encoding: utf-8
# frozen_string_literal: true

module Admin
  class PaymentsController < Admin::ApplicationController
    # == Modules ============================================================
    include Payable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      return render(create_payment)
    end

    def lookup
      if current_user && current_user.staff.admin?
        if @payment = Payment.find_by(transaction_id: params[:transaction_id], gateway_type: 'authorize.net')
          return render json: {
            id: "#{@payment.id}-#{@payment.gateway_type}-#{@payment.transaction_id}",
            status: @payment.status,
            message: 'Payment already Exists',
            errors: ['Payment has already been entered']
          }, status: 422
        end

        lookup_user

        attrs = Payment::Transaction::AuthNet::Lookup.run(params[:transaction_id], environment: :production)

        return render(create_payment(attrs, true))
      else
        return render json: {
          status: 'unauthorized',
          message: 'Not Authorized to create manual payments',
          errors: ['Not Authorized to create manual payments']
        }, status: 500
      end
    end

    def ach
      params[:gateway_type] = 'zions'
      if current_user && current_user.is_staff? && current_user.staff.check(:finances)
        if @payment = Payment.find_by(transaction_id: whitelisted_ach_payment_params[:transaction_id], gateway_type: 'zions')
          return render json: {
            id: "#{@payment.id}-#{@payment.gateway_type}-#{@payment.transaction_id}",
            status: @payment.status,
            message: 'Payment already Exists',
            errors: ['Payment has already been entered']
          }, status: 422
        end

        lookup_user

        return not_authorized("YOU ARE ADDING A PAYMENT TO A PREVIOUS YEAR", 422) unless @found_user&.traveler && params[:confirm_prev_year]

        attrs = @payment_transaction ||= Payment::Transaction::Zions.new(
          **whitelisted_ach_payment_params.
          to_h.
          deep_symbolize_keys.
          merge(
            ip_address: get_ip_address.presence || '127.0.0.1',
          )
        ).payment_attributes

        return render(create_payment(attrs, !Boolean.parse(params[:send_email])))
      else
        return render json: {
          status: 'unauthorized',
          message: 'Not Authorized to create manual payments',
          errors: ['Not Authorized to create manual payments']
        }, status: 500
      end
    rescue
      return render json: {
        status: 'error',
        message: $!.message,
        errors: [ $!.message, *$!.backtrace.first(10)]
      }, status: 500
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def whitelisted_ach_payment_params
        params.require(:payment).
          permit(
            :amount,
            :transaction_id,
            :transaction_type,
            :date_entered,
            :time_entered,
            :status,
            :notes,
            :remit_number,
            billing: [
              :customer_id,
              :company,
              :country_code_alpha3,
              :extended_address,
              :name,
              :phone,
              :email,
              :locality,
              :postal_code,
              :region,
              :street_address,
            ],
            gateway: [
              :bank_name,
              :transaction_type,
              :account_number,
              :account_type,
              :expiration,
              :routing_number
            ],
            settlement: [
              :status,
              :settlement_date,
              :voidable_date,
              :voided_date
            ],
            processor: [
              :message
            ],
            split: [
              :dus_id,
              :amount
            ]
          )
      end
  end
end
