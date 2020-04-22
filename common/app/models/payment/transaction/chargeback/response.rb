# encoding: utf-8
# frozen_string_literal: true


require_dependency 'payment/transaction/chargeback'

class Payment < ApplicationRecord
  module Transaction
    class Chargeback < Base
      class Response < BaseResponse
        def initialize(transaction)
          @transaction = transaction
        end

        def type
          'chargeback'
        end

        def transaction
          @transaction
        end
      end
    end
  end
end
