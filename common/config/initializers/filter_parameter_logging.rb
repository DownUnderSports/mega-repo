# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters |= [
  :password,
  :new_password,
  :new_password_confirmation,
  :register_secret,
  :certificate,
  :new_certificate,
  :new_certificate_confirmation,
  :card,
  :card_number,
  :nonce,
  :cvv,
  :expiration_year,
  :expiration_month,
  :postal_code,
  :number,
  :given_names,
  :surname
]

Raven.configure do |config|
  config.sanitize_fields = Rails.application.config.filter_parameters.map(&:to_s)
end
