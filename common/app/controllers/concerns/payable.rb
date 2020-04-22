# encoding: utf-8
# frozen_string_literal: true

module Payable
  extend ActiveSupport::Concern

  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================
  included do
    before_action :lookup_user, only: [:new, :create]
  end

  # == Actions ============================================================
  def new
    @client_token = gateway.client_token.generate
  end

  def show
    str, id, gateway_type, transaction_id = params[:id].to_s.match(/(\d+)-([^-]+)-(.*)/).to_a
    @payment = authorize Payment.includes(:items).find_by(id: id, gateway_type: gateway_type, transaction_id: transaction_id)
    return render json: {
      formatted_amount: @payment.amount.to_s(true),
      payment: @payment,
      status: @payment.status,
      items: @payment.items
    }, status: 200
  rescue
    return head 404
  end

  # == Cleanup ============================================================

  # == Utilities ==========================================================

  private
    def lookup_user
      @found_user = User.get(params[:user_id])
    end

    def create_payment(attrs = nil, skip_receipt = false, split = nil, skip_auto_split: false)
      @payment_transaction = attrs if attrs
      split = split.presence || whitelisted_payment_params[:split] || []
      begin
        if split.any? {|r| (r[:amount] || r['amount']).present? && (!(d = r[:dus_id] || r['dus_id']) || !User.get(d)&.payable?)}
          raise 'invalid split'
        end
      rescue
        return ({
          json: {
            status: 'failed',
            message: 'Invalid Split Amount',
            errors: [ 'User Not Found for Split Payment' ]
          },
          status: 422
        })
      end

      return ({
        json: {
          status: 'failed',
          message: 'Cannot Add Travelers to Previous Years',
          errors: [ 'Cannot Add Travelers to Previous Years' ]
        },
        status: 422
      }) unless @found_user.payable?

      @payment = @found_user.payments.create(
        **(attrs || payment_transaction.payment_attributes),
      )

      if @payment.successful
        main_amount = @payment.amount - (split.map {|r| StoreAsInt.money(r[:amount] || r['amount'] || 0) }.reduce(&:+) || 0)

        unless @found_user.traveler
          @found_user.create_traveler!(team: (params[:state_id].present? && Team.find_by(state_id: params[:state_id], sport_id: params[:sport_id])) || @found_user.team)
          @found_user.traveler.base_debits!
        end

        @payment.items << Payment::Item.new(
          traveler: @found_user.traveler,
          amount: main_amount,
          price: main_amount,
          name: 'Account Payment',
          description: "Account Payment for #{@found_user.print_names}",
          created_at: @payment.created_at
        )

        has_split = false
        description = "Split Payment for #{@found_user.basic_name}"

        split.each do |r|
          if (r[:dus_id] || r['dus_id']).present? && ((amount = StoreAsInt.money(r[:amount] || r['amount'])) > 0)
            u = User.get(r[:dus_id] || r['dus_id'])
            unless u.traveler
              u.create_traveler(team: u.team)
              u.traveler.base_debits!
            end
            (@payment.items << Payment::Item.new(
              traveler: u.traveler,
              amount: amount,
              price: amount,
              name: 'Split Account Payment',
              description: "Split Payment for #{u.print_names}",
              created_at: @payment.created_at
            )) && (has_split = true) && (description += "%SPLIT%#{u.basic_name}")
          end
        end

        if has_split
          description = description.split('%SPLIT%')
          if description.length == 2
            description = description.join(' and ')
          else
            description = description[0..-2].join(', ') + ", and #{description[-1]}"
          end
          @payment.items.each {|i| i.update(name: 'Split Account Payment', description: description)}
        elsif !skip_auto_split && @found_user.fundraising_array.present?
          item = @payment.traveler_items.find_by(amount: main_amount, traveler_id: @found_user.traveler.id)
          has_split = !!item
          item&.split! @found_user.fundraising_array
        end

        unless skip_receipt
          PaymentMailer.with(id: @payment.id, email: @payment.billing.with_indifferent_access[:email]).
            __send__(@payment.gateway_type.gsub(/\./, '_')).deliver_later(queue: :payment_mailer)

          if whitelisted_payment_params[:notes].present?
            PaymentMailer.with(payment_id: @payment.id, transaction_id: @payment.transaction_id, notes: whitelisted_payment_params[:notes]).
            payment_notes.deliver_later(queue: :payment_mailer)
          end
        end
      end

      return ({
        json: {
          id: "#{@payment.id}-#{@payment.gateway_type}-#{@payment.transaction_id}",
          status: @payment.status,
          message: attrs ? @payment.status : payment_transaction.message,
          errors: attrs ? @payment.errors.full_messages : payment_transaction.errors
        },
        status: @payment.successful ? 200 : 422
      })
    end

    def payment_transaction
      @payment_transaction ||= Payment::Transaction.const_get(
        (params[:payment][:gateway_type] || 'auth_net').camelize
      ).new(
        **whitelisted_payment_params.
        to_h.
        deep_symbolize_keys.
        merge(
          ip_address: get_ip_address.presence || '127.0.0.1',
          dus_id: @found_user.dus_id
        )
      )
    end

    def whitelisted_payment_params
      params.require(:payment).
        permit(
          :anonymous,
          :amount,
          :nonce,
          :card_number,
          :cvv,
          :expiration_month,
          :expiration_year,
          :gateway_type,
          :notes,
          billing: [
            :company,
            :country_code_alpha3,
            :extended_address,
            :name,
            :phone,
            :email,
            :first_name,
            :last_name,
            :locality,
            :postal_code,
            :region,
            :street_address,
          ],
          split: [
            :dus_id,
            :amount
          ]
        )
    end

    def get_ip_address
      header_hash[:HTTP_X_REAL_IP] ||
      header_hash[:HTTP_CLIENT_IP] ||
      request.remote_ip
    end
end
