# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'
require_dependency 'payment/transaction/auth_net/response'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      # == Constants ============================================================
      TRANSACTION_SUCCESS_STATUSES = []
      LIVE = 'https://api2.authorize.net/xml/v1/request.api'.freeze
      TEST = 'https://apitest.authorize.net/xml/v1/request.api'.freeze
      RESPONDER = Struct.new(:message, :transaction)

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
          Gateway.new(environment: Rails.env.production? ? :production : :development)
        end
      end

      # == Boolean Methods ======================================================
      def success?
        !!(result.transaction[:response_code].to_i == 1) || pending?
      rescue
        false
      end

      def pending?
        !!(result.transaction[:response_code].to_i == 4)
      rescue
        false
      end

      def failure?
        !success?
      end

      # == Instance Methods =====================================================
      def initialize(amount: 0, card_number:, cvv:, expiration_year:, expiration_month:, billing:, ip_address: '127.0.0.1', dus_id: '', notes: '', split: [], anonymous: false, **opts)
        @amount = StoreAsInt.money(amount || 0)
        @card_number = card_number || ''
        @cvv = cvv || ''
        @expiration_year = (expiration_year || Date.today.year.to_s)[-2..-1]
        @expiration_month = expiration_month || ''
        @billing = billing || {}
        @billing[:country_code_alpha3] ||= 'USA'
        @billing[:notes] = notes.presence
        @ip_address = ip_address
        @options = opts
        @dus_id = dus_id || ''
        @split = split || []
        @anonymous = Boolean.strict_parse(anonymous)
        self
      end

      def payment_attributes
        {
          gateway_type: response.type,
          amount: @amount,
          billing: billing,
          gateway: response.gateway,
          processor: response.processor,
          risk: response.risk.merge(decision),
          settlement: response.settlement,
          successful: !!success?,
          status: status,
          transaction_type: response.account_type,
          transaction_id: transaction[:trans_id],
          anonymous: @anonymous,
        }
      end

      def billing
        @billing
      end

      def errors
        success? ? nil : [transaction[:errors] ? transaction[:errors][:error][:error_text] : result.message[:text]]
      end

      def message
        @message ||= (
          success? ?
          result.message[:text] :
          get_error_message
        ).downcase
      rescue
        @message = 'unknown'
      end

      def get_error_message
        e = (transaction[:errors] || {})[:error]
        if e.is_a? Array
          e = e[0]
        end
        e[:error_text]
      rescue
        if pending?
          begin
            result.message[:text]
          rescue
            'pending'
          end
        else
          'failed'
        end
      end

      def response
        @response ||= Response.new(result)
      end

      def result
        @result ||= gateway.sale(
          amount: @amount,
          card_number: @card_number,
          cvv: @cvv,
          expiration_year: @expiration_year,
          expiration_month: @expiration_month,
          billing: @billing,
          ip_address: @ip_address,
          options: @options,
          dus_id: @dus_id,
          split: @split
        )
        @result
      end

      def status
        pending? ? 'PENDING REVIEW' : message
      end

      def transaction
        # p result
        @transaction ||= result.transaction
      end

      def decision
        {
          decision: pending? ? 'pending review' : (success? ? 'approved' : 'rejected')
        }
      end
    end
  end
end
