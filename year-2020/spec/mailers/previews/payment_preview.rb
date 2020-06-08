# Preview all emails at http://localhost:3000/rails/mailers/payment
class PaymentPreview < ActionMailer::Preview
  def authorize_net
    PaymentMailer.with(id: Payment.successful.first.id, email: 'sampsonsprojects@gmail.com').authorize_net
  end
end
