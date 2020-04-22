# encoding: utf-8
# frozen_string_literal: true

require 'uri'
require 'net/https'
require_dependency 'payment/transaction/auth_net'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class BatchList < AuthNet::Base
        def initialize(environment: :development, start_date: Date.today, end_date: nil)
          @environment = environment.to_sym
          @start_date = start_date.to_date
          @end_date = (end_date || (@start_date + 30.days)).to_date
        end

        def run
          s_date = nil
          e_date = nil

          if @end_date > (@start_date + 30.days)
            s_date = @start_date + 31.days
            e_date = @end_date
            @end_date = @start_date + 30.days
          end

          list = (result[:batch_list] || {})[:batch] || []
          list = [ list ] if list.is_a? Hash
          (list.map {|b| b[:batch_id].presence }.select(&:present?)) + (
            s_date ?
            self.class.run(environment: environment, start_date: s_date, end_date: e_date) :
            []
          )
        rescue
          p $!.message
          p $!.backtrace
          []
        end

        def result_key
          :get_settled_batch_list_response
        end

        def build_request
          <<-XML
            <getSettledBatchListRequest xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
              <merchantAuthentication>
                <name>#{credentials[:id]}</name>
                <transactionKey>#{credentials[:key]}</transactionKey>
              </merchantAuthentication>
              <firstSettlementDate>#{@start_date}T00:00:00Z</firstSettlementDate>
              <lastSettlementDate>#{@end_date}T00:00:00Z</lastSettlementDate>
            </getSettledBatchListRequest>
          XML
        end
      end
    end
  end
end
