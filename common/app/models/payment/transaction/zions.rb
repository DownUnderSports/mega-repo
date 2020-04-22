# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/transaction'

class Payment < ApplicationRecord
  module Transaction
    class Zions < Base
      # == Constants ============================================================
      TRANSACTION_SUCCESS_STATUSES = []

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
        @status =~ /^(posted|approved|settled|sent|authorized)$/i
      rescue
        false
      end

      def failure?
        !success?
      end

      # == Instance Methods =====================================================
      def initialize(transaction_id:, transaction_type:, billing:, gateway:, settlement:, processor:, amount: 0, date_entered: nil, time_entered: nil, ip_address: '127.0.0.1', notes: '', split: [], status: 'rejected', remit_number: nil, **opts)
        @amount = StoreAsInt.money(amount || 0)
        @transaction_id = transaction_id
        @transaction_type = (transaction_type.to_s =~ /ach/i) ? 'ach' : 'check'
        @gateway = gateway || {}
        @gateway[:account_number] = "XXXX#{@gateway[:account_number].to_s[-4..-1]}"
        @settlement = settlement || {}
        @processor = processor || {}
        @billing = billing || {}
        @billing[:notes] = notes.presence
        @billing[:split] = split
        @ip_address = ip_address
        @options = opts
        @split = split || []
        @status = (status || 'rejected').to_s.downcase.gsub("\n", ' ')
        @created_at = Time.zone.parse("#{(date_entered.presence || Date.today).to_s} #{(time_entered.presence || Time.now.strftime('%H:%M')).to_s}")
        @remit_number = remit_number
        self
      end

      def payment_attributes
        {
          gateway_type: 'zions',
          amount: @amount,
          billing: @billing,
          gateway: @gateway,
          processor: @processor,
          risk: {},
          settlement: @settlement,
          successful: !!success?,
          status: @status,
          transaction_type: @transaction_type,
          transaction_id: @transaction_id,
          remit_number: (@remit_number.presence || "#{@created_at.to_date.to_s}-#{
            (@transaction_type.to_s =~ /card/) ? 'CC' : @transaction_type.upcase
          }").gsub(/\s/, ''),
          created_at: @created_at
        }
      end

      def errors
        success? ? nil : [ @status ]
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
        status
      rescue
        'failed'
      end

      def transaction
        @transaction ||= {}
      end
    end
  end
end
