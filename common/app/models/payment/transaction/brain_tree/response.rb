# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction/brain_tree'

class Payment < ApplicationRecord
  module Transaction
    class BrainTree < Base
      class Response < BaseResponse
        def initialize(transaction)
          @transaction = transaction
        end

        def type
          'braintree'
        end

        def processor
          super(
            begin
              {
                code: transaction.processor_response_code,
                text: transaction.processor_response_text,
                additional: transaction.additional_processor_response,
              }
            rescue
              {}
            end
          )
        end

        def settlement
          super(
            begin
              {
                code: transaction.processor_settlement_response_code,
                text: transaction.processor_settlement_response_text,
              }
            rescue
              {}
            end
          )
        end

        def gateway
          super(
            begin
              {
                text: transaction.gateway_rejection_reason,
              }
            rescue
              {}
            end
          )
        end

        def risk
          super(
            begin
              {
                id: transaction.risk_data.id,
                decision: transaction.risk_data.decision,
                device_data_captured: transaction.risk_data.device_data_captured
              }
            rescue
              {}
            end
          )
        end

        def transaction
          @transaction
        end
      end
    end
  end
end
