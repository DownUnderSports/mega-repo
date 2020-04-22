# encoding: utf-8
# frozen_string_literal: true

class PaymentMailer < ImportantMailer
  # default use_account: :receipt

  def authorize_net
    @payment = Payment.find(params[:id])
    email = params[:email].presence || @payment.billing[:email].presence || 'mail@downundersports.com'

    mail skip_filter: true, to: email, subject: 'Down Under Sports - Receipt'
  end

  def zions
    @payment = Payment.find(params[:id])
    email = params[:email].presence || @payment.billing[:email].presence || 'mail@downundersports.com'

    mail skip_filter: true, to: email, subject: 'Down Under Sports - Receipt'
  end

  def transfer
    @payment = Payment.find(params[:id])
    email = params[:email].presence || @payment.billing[:email].presence || 'mail@downundersports.com'

    mail skip_filter: true, to: email, subject: 'Down Under Sports - Receipt'
  end

  def payment_notes
    @payment_id = params[:payment_id]
    @payment = Payment.find_by(id: @payment_id)
    @transaction_id = params[:transaction_id].presence
    @notes = params[:notes]

    mail to: %w[ it@downundersports.com karen@downundersports.com ], subject: 'Notes submitted with website payment' do |format|
      format.text
    end
  end
end
