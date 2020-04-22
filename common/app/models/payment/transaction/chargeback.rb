# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'
require_dependency 'payment/transaction/transfer/response'

class Payment < ApplicationRecord
  module Transaction
    class Chargeback < Base
      # == Constants ============================================================
      class CatchallWithId
        def initialize(id)
          @id = id
        end

        def method_missing(*args, &block)
          self
        end

        def to_h
          {}
        end

        def to_json
          to_h
        end

        def id
          @id
        end
      end

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
          {
            type: 'EMS',
            reference_id: @reference_id
          }
        end
      end

      # == Boolean Methods ======================================================
      def success?
        true
      end

      def failure?
        !success?
      end

      # == Instance Methods =====================================================
      def initialize(payment:, amount: nil, reference_id: nil, created_at: nil)
        @payment = Payment[payment]
        @amount = -(StoreAsInt.money(amount || @payment.amount).abs)
        @reference_id = reference_id || @payment.transaction_id
        @created_at = created_at || Time.zone.now
        self
      end

      def payment_attributes
        super.merge(
          amount: @amount,
          remit_number: "#{@created_at.to_date}-CHARGEBACK",
          user_id: @payment.user_id,
          category: :chargeback,
          gateway: {
            type: "chargeback",
            chargeback_transaction_id: @payment.transaction_id,
            chargeback_transaction_type: @payment.transaction_type,
            chargeback_gateway: @payment.gateway_type
          },
          items_attributes: [
            {
              traveler_id: @payment.user.traveler.id,
              amount: @amount,
              price: @amount,
              quantity: 1,
              name: 'Payment Chargeback',
              description: get_description,
              created_at: @created_at
            }
          ],
          created_at: @created_at
        )
      end

      def get_description
        "#{
          if @payment.anonymous?
            "Payment Chargeback from Anonymous Donor"
          elsif billing["name"].present?
            "Payment Chargeback from #{billing["name"]}"
          else
            "Payment Chargeback"
          end
        } (#{@payment.created_at.to_date.to_s(:long)})"

      end

      def billing
        @billing ||= @payment&.billing.presence || {}
      end

      def errors
        nil
      end

      def message
        'success'
      end

      def status
        @status ||= 'successful'
      end

      def transaction_type
        'chargeback'
      end

      def transaction
        @transaction ||= CatchallWithId.new(@reference_id)
      end
    end
  end
end
