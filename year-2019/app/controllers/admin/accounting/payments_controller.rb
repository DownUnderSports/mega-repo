# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class PaymentsController < ::Admin::PaymentsController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      # def create
      #   total = StoreAsInt.money(whitelist[:amount])
      #   bad_checks = []
      #   payments = []
      #
      #   whitelist[:checks].each_with_index do |check, i|
      #     amount = StoreAsInt.money(check[:amount])
      #     total -= amount
      #     if total < 0
      #       return render json: {
      #         errors: ['Check Sums are greater than deposit amount']
      #       }, status: 422
      #     end
      #     gateway = (check[:gateway] = whitelist[:gateway].dup.merge(**check[:gateway]))
      #     billing = check[:billing] = check[:billing].dup.to_h.with_indifferent_access
      #     unless u = User.get(check[:dus_id])
      #       return render json: {
      #         errors: ["User #{check[:dus_id]} not found for check ##{gateway[:check_number]}"]
      #       }
      #     end
      #
      #     billing[:email] = billing[:email].presence || u.main_email
      #
      #     %i[
      #       transaction_type
      #       amount
      #       date_entered
      #       time_entered
      #       remit_number
      #       status
      #     ].each do |k|
      #       check[k] = check[k].presence || whitelist[k]
      #     end
      #     check[:transaction_id] = "#{gateway[:transaction_type]}#{gateway[:deposit_number].rjust(6, '0')}-#{gateway[:check_number].rjust(6, '0')}".upcase
      #     payments << [
      #       u,
      #       check,
      #       Payment::Transaction::Zions.new(settlement: {}, processor: {message: 'submitted'}, **check).payment_attributes
      #     ]
      #   end
      #
      #   return render json: {
      #     payments: payments.map do |user, check, attrs|
      #       if Payment.find_by(transaction_id: check[:transaction_id])
      #         {
      #           check: check,
      #           json: {
      #             errors: ["#{check[:transaction_type].capitalize} #{check[:gateway][:check_number]} for Deposit #{check[:gateway][:deposit_number]} has already been submitted"]
      #           },
      #           status: 422
      #         }
      #       else
      #         @found_user = user
      #         create_payment(attrs, !Boolean.parse(check[:gateway][:send_email]), check[:split].presence).merge(check: check)
      #       end
      #     end,
      #   }, status: 200
      # end

      # == Cleanup ============================================================

      # == Utilities ==========================================================

      private
        def lookup_user
          @found_user
        end

        def is_proxy?
          super && current_user.is_staff? && current_user.staff.check(:finances)
        end

        def whitelist
          @whitelist ||= whitelisted_payment_params.to_h.deep_symbolize_keys
        end

        def whitelisted_payment_params
          params.require(:payment).permit(
            :transaction_type,
            :amount,
            :date_entered,
            :time_entered,
            :remit_number,
            :status,
            gateway: %i[
              transaction_type
              deposit_number
              deposited_items
            ],
            checks: [
              :dus_id,
              :date_entered,
              :time_entered,
              :amount,
              :transaction_type,
              billing: %i[
                company
                name
                email
                phone
                country_code_alpha3
                extended_address
                locality
                postal_code
                region
                street_address
              ],
              gateway: %i[
                transaction_type
                routing_number
                account_number
                check_number
                send_email
                bank_name
              ],
              split: %i[
                dus_id
                amount
              ]
            ]
          )
        end
    end
  end
end
