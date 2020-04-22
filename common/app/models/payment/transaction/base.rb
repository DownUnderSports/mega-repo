# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'

class Payment < ApplicationRecord
  module Transaction
    class Base
      # == Constants ============================================================
      TRANSACTION_SUCCESS_STATUSES = []

      class BaseResponse
        def type(other = {})
          'base'
        end

        def processor(code: 'unknown', text: 'unknown', **opts)
          {
            code: code,
            text: text,
            **opts
          }
        end

        def settlement(code: 'unknown', text: 'unknown', **opts)
          {
            code: code,
            text: text,
            **opts
          }
        end

        def gateway(**opts)
          {
            type: type,
            **opts
          }
        end

        def risk(id: 'unknown', decision: 'unknown', **opts)
          {
            id: id,
            decision: decision,
            **opts
          }
        end
      end

      class Catchall
        def self.method_missing(*args, &block)
          self
        end

        def self.to_h
          {}
        end

        def self.to_json
          to_h
        end

        def self.id
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
          Catchall
        end
      end

      # == Boolean Methods ======================================================
      def success?
        false
      end

      def failure?
        true
      end

      # == Instance Methods =====================================================
      def payment_attributes
        {
          amount: @amount,
          billing: billing,
          gateway: response.gateway,
          gateway_type: response.type,
          processor: response.processor,
          risk: response.risk,
          settlement: response.settlement,
          successful: !!success?,
          status: status,
          transaction_type: transaction_type,
          transaction_id: transaction.id,
          anonymous: @anonymous,
        }
      end

      def billing
        {}
      end

      def errors
        [
          'Invalid Transaction Type'
        ]
      end

      def message
        errors.first
      end

      def response
        @response ||= self.class.const_get(:Response).new(transaction)
      rescue NameError => e
        p e, e.message
        if(e.message =~ /::Response$/)
          @response ||= BaseResponse.new(transaction)
        else
          raise
        end
      end

      def result
        @result ||= Catchall
      end

      def status
        @status ||= 'failed'
      end

      def transaction
        @transaction ||= Catchall
      end

      def transaction_type
        @transaction_type ||= 'base'
      end

      private
        def gateway
          self.class.create_gateway
        end
    end
  end
end
