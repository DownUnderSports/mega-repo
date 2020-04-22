# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction/auth_net'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class Response < BaseResponse
        def initialize(result)
          @result = result
        end

        def type
          'authorize.net'
        end

        def processor
          super(
            begin
              {
                **message
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
                code: settlement_code,
                text: settlement_text
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
                auth_code: transaction[:auth_code],
                response_code: transaction[:response_code],
                trans_id: transaction[:trans_id],
                ref_trans_id: transaction[:ref_trans_id],
                trans_hash: transaction[:trans_hash],
                trans_hash_sha2: transaction[:trans_hash_sha2],
                account_number: transaction[:account_number],
                account_type: account_type,
                invoice_number: transaction[:invoice_number],
                order_description: transaction[:order_description]
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
                avs_result_code: transaction[:avs_result_code],
                cvv_result_code: transaction[:cvv_result_code],
                cavv_result_code: transaction[:cavv_result_code]
              }
            rescue
              {}
            end
          )
        end

        def settlement_text
          transaction[:messages][:message][:description]
        rescue
          if transaction[:transaction_status].present?
            @settlement_text ||= transaction[:transaction_status].to_s == 'settledSuccessfully' ? 'This transaction has been approved.' : transaction[:transaction_status]
          else
            'unknown'
          end
        end

        def settlement_code
          transaction[:messages][:message][:code]
        rescue
          transaction[:response_code] ||
          'unknown'
        end

        def account_type
          transaction[:account_type] ||= transaction[:payment][:credit_card][:card_type]
        rescue
          'unknown'
        end

        def transaction
          @result.transaction
        end

        def message
          @result.message
        end
      end
    end
  end
end
