# encoding: utf-8
# frozen_string_literal: true

require 'uri'
require 'net/https'
require_dependency 'payment/transaction/auth_net'

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class Gateway < AuthNet::Base
        def initialize(environment: :development)
          @environment = environment.to_sym
        end

        def sale(amount:, card_number:, expiration_month:, expiration_year:, cvv:, billing:, ip_address:, dus_id:, split:, **opts)
          @amount = amount
          @card_number = card_number
          @expiration_month = expiration_month
          @expiration_year = expiration_year.to_s[-2..-1]
          @cvv = cvv
          @billing = billing
          @ip_address = ip_address
          @options = opts
          @dus_id = dus_id
          @split = (split || []).map {|r| (r || {}).deep_symbolize_keys }.select {|r| valid_split(r)}
          result
        end

        def address
          "#{
            @billing[:street_address]
          }#{
            @billing[:extended_address].present? ?
            ", #{@billing[:extended_address]}" :
            ''
          }"
        end

        def first_name
          @billing[:first_name] || @billing[:name].split(' ')[0]
        end

        def last_name
          @billing[:last_name] || @billing[:name].split(' ')[1..-1].join(' ')
        end

        def build_request
          main_amount = @amount - (@split.map {|r| StoreAsInt.money(r[:amount])}.reduce(&:+) || 0)
          rows = [{dus_id: @dus_id, amount: main_amount}, *@split]

          @invoice_number = rows.map {|r| User.get(r[:dus_id]).dus_id }.join(', ').strip
          @description = "Payment for: #{@invoice_number}"

          if @invoice_number.size > 19
            @invoice_number = @invoice_number[0...16] + '...'
          end

          i = 0

          <<-XML
            <createTransactionRequest xmlns="AnetApi/xml/v1/schema/AnetApiSchema.xsd">
              <merchantAuthentication>
                <name>#{credentials[:id]}</name>
                <transactionKey>#{credentials[:key]}</transactionKey>
              </merchantAuthentication>
              <transactionRequest>
                <transactionType>authCaptureTransaction</transactionType>
                <amount>#{@amount}</amount>
                <payment>
                  <creditCard>
                    <cardNumber>#{@card_number}</cardNumber>
                    <expirationDate>20#{@expiration_year}-#{@expiration_month}</expirationDate>
                    <cardCode>#{@cvv}</cardCode>
                  </creditCard>
                </payment>
                <order>
                  <invoiceNumber>#{ @invoice_number }</invoiceNumber>
                  <description>#{ @description }</description>
                </order>
                <lineItems>
                  #{
                    rows.map do |r|
                      if r[:dus_id].present?
                        i += 1
                        line_item(i: i, **r)
                      else
                        ''
                      end
                    end.join("\n")
                  }
                </lineItems>
                <billTo>
                  <firstName>#{first_name}</firstName>
                  <lastName>#{last_name}</lastName>
                  <company>#{@billing[:company]}</company>
                  <address>#{address}</address>
                  <city>#{@billing[:locality]}</city>
                  <state>#{@billing[:region]}</state>
                  <zip>#{@billing[:postal_code] || @billing[:zip]}</zip>
                  <country>#{@billing[:country_code_alpha3]}</country>
                </billTo>
                <customerIP>#{@ip_address}</customerIP>
                <userFields>
                  <userField>
                    <name>dus_id</name>
                    <value>#{@dus_id}</value>
                  </userField>
                  <userField>
                    <name>notes</name>
                    <value>#{@billing[:notes] || 'No Notes Submitted'}</value>
                  </userField>
                </userFields>
              </transactionRequest>
            </createTransactionRequest>
          XML
        end

        def line_item(dus_id:, amount:, i: 1)
          amount = StoreAsInt.money(amount || 0)
          <<-XML
            <lineItem>
              <itemId>#{i || 1}</itemId>
              <name>#{dus_id}</name>
              <description>Payment toward #{dus_id}</description>
              <quantity>1</quantity>
              <unitPrice>#{StoreAsInt.money(amount).to_s}</unitPrice>
            </lineItem>
          XML
        end

        def build_result
          h = {}
          begin
            if @split.present?
              a = StoreAsInt.money(0)
              @split.each do |r|
                if r[:dus_id].present? || r[:amount].present?
                  if !User.get(r[:dus_id])
                    h = {
                      error_response: {
                        messages: {
                          message: {
                            code: 'SPLITERROR',
                            text: "Invalid Payment Split - User #{r[:dus_id]} not found"
                          }
                        }
                      }
                    }
                    raise 'Invalid Split'
                  elsif ((a += StoreAsInt.money(r[:amount])) >= @amount)
                    h = {
                      error_response: {
                        messages: {
                          message: {
                            code: 'SPLITERROR',
                            text: 'Invalid Payment Split - Total split amounts must be less than the total payment amount'
                          }
                        }
                      }
                    }
                    raise 'Invalid Split'
                  end
                end
              end
            end
            h = super
          rescue
            p $!.message
            p $!.backtrace
          end

          begin
            t = h[:create_transaction_response][:transaction_response] || h
            t[:invoice_number] = @invoice_number
            t[:order_description] = @order_description
            self.class.responder.new(h[:create_transaction_response][:messages][:message], t)
          rescue
            self.class.responder.new(h[:error_response][:messages][:message], {trans_id: find_trans_id(h)})
          end
        end

        def find_trans_id(h)
          h.each do |k, v|
            return v[:trans_id] if v.is_a?(Hash) && v[:trans_id]
          end

          h.each do |k, v|
            if v.is_a? Hash
              found = find_trans_id(v)
              return found if found
            end
          end
        rescue
          nil
        end

        def valid_split(r)
          begin
            !!((StoreAsInt.money(r[:amount] || 0) > 0) && r[:dus_id].present? && User.get(r[:dus_id]))
          rescue
            false
          end
        end
      end
    end
  end
end
