# encoding: utf-8
# frozen_string_literal: true

require 'uri'
require 'net/https'
require_dependency 'payment/transaction/auth_net'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class Lookup < AuthNet::Base
        def self.run(transaction_id, **opts)
          new(**opts, transaction_id: transaction_id).run
        end

        def self.get_ids(start_date: Date.today, end_date: nil, **opts)
          batches = BatchList.run(**opts, start_date: start_date, end_date: end_date)
          trans_ids = []
          batches.each do |b_id|
            trans_ids += List.run(**opts, batch_id: b_id)
          end

          (
            trans_ids -
            Payment.
            where(
              gateway_type: 'authorize.net',
              transaction_id: trans_ids
            ).pluck(:transaction_id)
          )
        end

        def self.get_all(**opts)
          self.get_ids(**opts).map do |t_id|
            run t_id, **opts
          end
        end

        def initialize(environment: :development, transaction_id:, **opts)
          @environment = environment.to_sym
          @transaction_id = transaction_id
        end

        def run
          {
            gateway_type: parsed.type,
            amount: StoreAsInt.money(parsed.transaction[:auth_amount]) * multiplier,
            billing: billing,
            gateway: parsed.gateway,
            processor: parsed.processor,
            risk: parsed.risk,
            settlement: parsed.settlement,
            successful: successful,
            status: successful ? 'successful' : parsed.settlement[:text],
            transaction_type: parsed.account_type,
            transaction_id: parsed.transaction[:trans_id],
            remit_number: "#{self.parsed_created_at.to_date.to_s}-CC",
            created_at: self.parsed_created_at
          }
        end

        def parsed_created_at
          (
            parsed.transaction[:submit_time_local] &&
            Time.zone.parse(parsed.transaction[:submit_time_local])
          ) || Time.zone.now
        end

        def parsed
          @parsed ||= Response.new(result)
        end

        def billing
          billed = parsed.transaction[:bill_to]
          {
            company: billed[:company],
            name: "#{billed[:first_name]} #{billed[:last_name]}",
            street_address: billed[:address],
            extended_address: nil,
            locality: billed[:city],
            region: billed[:state],
            postal_code: billed[:zip],
            country_code_alpha3: billed[:country],
            phone: billed[:phone_number],
            email: nil,
            notes: nil,
          }
        rescue
          {}
        end

        def successful
          !!(parsed.transaction[:response_code].to_i == 1)
        end

        def multiplier
          @multiplier ||= (parsed.transaction[:transaction_type].to_s =~ /refund/) \
            ? -1 \
            : 1
        end

        def build_request
          <<-XML
            <getTransactionDetailsRequest xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
              <merchantAuthentication>
                <name>#{credentials[:id]}</name>
                <transactionKey>#{credentials[:key]}</transactionKey>
              </merchantAuthentication>
              <transId>#{@transaction_id}</transId>
            </createTransactionRequest>
          XML
        end

        def build_result
          h = super
          begin
            t = h[:get_transaction_details_response][:transaction] || h
            if t[:order] && t[:order].is_a?(Hash)
              t[:invoice_number] = t[:order][:invoice_number]
              t[:order_description] = t[:order][:description]
            end
            self.class.responder.new(h[:get_transaction_details_response][:messages][:message], t)
          rescue
            self.class.responder.new(h[:error_response][:messages][:message], {})
          end
        end
      end
    end
  end
end
