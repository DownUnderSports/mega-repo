# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'
require_dependency 'payment/transaction/brain_tree/response'

class Payment < ApplicationRecord
  module Transaction
    class BrainTree < Base
      # == Constants ============================================================
      TRANSACTION_SUCCESS_STATUSES = [
        ::Braintree::Transaction::Status::Authorizing,
        ::Braintree::Transaction::Status::Authorized,
        ::Braintree::Transaction::Status::Settled,
        ::Braintree::Transaction::Status::SettlementConfirmed,
        ::Braintree::Transaction::Status::SettlementPending,
        ::Braintree::Transaction::Status::Settling,
        ::Braintree::Transaction::Status::SubmittedForSettlement,
      ]

      # == Attributes ===========================================================

      # == Extensions ===========================================================

      # == Relationships ========================================================

      # == Validations ==========================================================

      # == Scopes ===============================================================

      # == Callbacks ============================================================

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================
      class << self
        def create_gateway
          ::Braintree::Gateway.new(
            environment: Rails.env.production? ? :production : :sandbox,
            **(
              Rails.application.credentials.dig(:braintree, Rails.env.to_sym) ||
              {
                merchant_id: ENV["BT_MERCHANT_ID"],
                public_key:  ENV["BT_PUBLIC_KEY"],
                private_key: ENV["BT_PRIVATE_KEY"]
              }
            )

          )
        end
      end

      # == Boolean Methods ======================================================
      def success?
        result.success?
      end

      def failure?
        !success?
      end

      # == Instance Methods =====================================================
      def initialize(amount: 0, nonce:, billing: {}, anonymous: false, **opts)
        @amount = StoreAsInt.money(amount || 0)
        @nonce = nonce
        @billing = billing || {}
        @anonymous = Boolean.strict_parse(anonymous)
        @options = {
          submit_for_settlement: true,
          **opts
        }
        self
      end

      def billing
        failure? ?
          result.params :
          {
            address: result.address,
            credit_card: result.credit_card,
            customer: result.customer,
            merchant_account: result.merchant_account,
            new_transaction: result.new_transaction,
            payment_method: result.payment_method,
            settlement_batch_summary: result.settlement_batch_summary,
            subscription: result.subscription,
            billing: transaction.billing_details
          }
      end

      def errors
        success? ? nil : result.errors
      end

      def message
        failure? ? result.message : 'success'
      end

      def result
        @result ||= gateway_transaction.sale(
          amount: @amount.to_s,
          payment_method_nonce: @nonce,
          billing: @billing,
          options: @options
        )
      end

      def status
        @status ||= transaction.status
      end

      def transaction
        @transaction ||= result.transaction
      end

      def transaction_type
        @transaction_type ||= transaction.payment_instrument_type
      end

      private
        def gateway_transaction
          @gateway_transaction ||= gateway.transaction
        end
    end
  end
end
