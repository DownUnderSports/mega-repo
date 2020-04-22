# encoding: utf-8
# frozen_string_literal: true

require 'uri'
require 'net/https'
require_dependency 'payment/transaction/auth_net' 

class Payment < ApplicationRecord
  module Transaction
    class AuthNet < Base
      class Base
        def self.live_url
          Payment::Transaction::AuthNet::LIVE
        end

        def self.test_url
          Payment::Transaction::AuthNet::TEST
        end

        def self.transaction_success_statuses
          Payment::Transaction::AuthNet::TRANSACTION_SUCCESS_STATUSES
        end

        def self.responder
          Payment::Transaction::AuthNet::RESPONDER
        end

        def self.run(**opts)
          new(**opts).run
        end

        def environment
          @environment ||= :development
        end

        def gateway_url
          environment == :production ? self.class.live_url : self.class.test_url
        end

        def send_request
          xml = Nokogiri::XML(build_request.gsub(/\s+</, '<')).to_xml
          url = URI.parse(gateway_url)

          request = Net::HTTP::Post.new(url.path)
          request.content_type = 'text/xml'
          request.body = xml
          connection = Net::HTTP.new(url.host, url.port)
          connection.use_ssl = true
          connection.verify_mode = OpenSSL::SSL::VERIFY_PEER
          connection.start {|http| http.request(request)}
        end

        def credentials
          @credentials ||= Rails.application.credentials.dig(:authorize_net, environment)
        end

        def response
          @response ||= send_request
        end

        def result
          @result ||= result_key ? build_result[result_key] : build_result
        end

        def result_key
          nil
        end

        def build_result
          h = {}
          begin
            h = Hash.from_xml(response.body).
            deep_transform_keys { |key| key.underscore.to_sym }
          rescue
            p $!.message
            p $!.backtrace
          end
        end
      end
    end
  end
end
