# encoding: utf-8
# frozen_string_literal: true


require_dependency 'payment/transaction/transfer'

class Payment < ApplicationRecord
  module Transaction
    class Transfer < Base
      class Response < BaseResponse
        def initialize(transaction)
          @transaction = transaction
        end

        def type
          'transfer'
        end

        def transaction
          @transaction
        end
      end
    end
  end
end
