# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'
require_dependency 'payment/transaction/transfer/response'

class Payment < ApplicationRecord
  module Transaction
    class Transfer < Base
      # == Constants ============================================================

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
          {}
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
      def initialize(amount: 0, from:, to: :shirts, quantity: 1, is_refund: false, is_uniform: false)
        @amount = StoreAsInt.money(amount || 0)
        @from = User.get(from)
        @to = to == :shirts ? nil : User.get(to)
        @quantity = quantity.to_i
        @is_refund = Boolean.parse(is_refund)
        @is_uniform = Boolean.parse(is_uniform)
        @single_item = @is_refund || @is_uniform
        @billing = @single_item ? single_item_billing : (billing || {})
        @anonymous = false
        self
      end

      def payment_attributes
        price = (@amount / @quantity)
        item_attrs = {
          traveler_id: @from.traveler.id,
          amount: -@amount,
          price: -price,
          quantity: @quantity,
          name: 'Transfer Payment',
          description: get_description(price)
        }
        super.merge(
          amount: @single_item ? -@amount : @amount,
          remit_number: "#{Date.today}-#{@is_refund ? "REFUND" : "TXFR"}",
          user_id: @from.id,
          category: :transfer,
          items_attributes: [
            item_attrs,
            *(
              @single_item ?
                nil :
                [
                  item_attrs.merge(
                    **(
                      @to ?
                        {} :
                        {
                          name: 'Shirt Payment',
                          description: item_attrs[:description].sub('Transfer for ', '')
                        }
                    ),
                    traveler_id: @to&.get_or_create_traveler&.id,
                    amount: @amount,
                    price: price,
                  )
                ]
            )
          ]
        )
      end

      def get_description(price)
        if @single_item
          @is_refund ? "Overpayment Refund" : "Transfer for Uniform Re-Order"
        else
          @to ?
            "Transfer from #{@from.basic_name} to #{@to.basic_name}" :
            "Transfer for #{@quantity} shirt#{@quantity > 1 ? 's' : ''} @ #{price.to_s(true).sub(/\.00$/, '')}/shirt"
        end
      end

      def billing
        @billing ||= {
          from: @from.dus_id,
          to: @to&.dus_id || :shirts
        }
      end

      def single_item_billing
        {
          name:                "Down Under Sports",
          street_address:      "PO Box 6010",
          region:              "UT",
          company:             "International Sports Specialists, Inc",
          locality:            "North Logan",
          postal_code:         "84341",
          country_code_alpha3: "USA"
        }
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
        'transfer'
      end
    end
  end
end
