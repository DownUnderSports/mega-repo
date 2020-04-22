# encoding: utf-8
# frozen_string_literal: true

require 'uri'
require 'net/https'
require_dependency 'payment/transaction/auth_net'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class List < AuthNet::Base
        def initialize(batch_id:, offset: 1, environment: :development)
          @environment = environment.to_sym
          @batch_id = batch_id
          @offset = (offset || 1).to_i
          @offset = 1 if @offset < 1
        end

        def run
          list = (result[:transactions] || {})[:transaction] || []
          list = [ list ] if list.is_a? Hash
          (list.map {|b| b[:trans_id].presence }.select(&:present?)) + (
            count > 99 ?
            self.class.run(environment: environment, batch_id: @batch_id, offset: @offset + 1) :
            []
          )
        rescue
          p $!.message
          p $!.backtrace
          []
        end

        def count
          result[:total_num_in_result_set].to_i
        end

        def response
          @response ||= send_request
        end

        def result_key
          :get_transaction_list_response
        end

        def build_request
          <<-XML
            <getTransactionListRequest xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
              <merchantAuthentication>
                <name>#{credentials[:id]}</name>
                <transactionKey>#{credentials[:key]}</transactionKey>
              </merchantAuthentication>
              <batchId>#{@batch_id}</batchId>
              <sorting>
                <orderBy>submitTimeUTC</orderBy>
                <orderDescending>true</orderDescending>
              </sorting>
              <paging>
                <limit>100</limit>
                <offset>#{@offset}</offset>
              </paging>
            </getTransactionListRequest>
          XML
        end
      end
    end
  end
end
