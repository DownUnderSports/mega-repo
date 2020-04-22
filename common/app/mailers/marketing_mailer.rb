# encoding: utf-8
# frozen_string_literal: true

class MarketingMailer < ApplicationMailer
  def mail(email: nil, **params)
    params[:to] = email if email
    has_email = false

    [:to, :cc, :bcc].each do |h|
      if params[h].present?
        params[h] = filter_emails(params[h]).presence
        has_email ||= params[h].present?
      end
    end

    return false unless has_email

    if block_given?
      super(**params) do |format|
        yield format
      end
    else
      super(**params)
    end
  end
end
