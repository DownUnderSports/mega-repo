# encoding: utf-8
# frozen_string_literal: true

# ThankYouTicket description
class ThankYouTicket < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :user, inverse_of: :thank_you_tickets

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================
  after_commit :reload if -> { uuid.nil? }

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def as_json
    reload if persisted? && uuid.nil?
    super.tap do |h|
      h[:link] = link_path
      h[:qr_code] = qr_code_path
    end
  end

  def qr_code_path
    "/api/qr_codes/#{Base64.strict_encode64(url)}"
  end

  def link_path
    "/redeem_ticket/#{uuid}#{user ? "?dus_id=#{user.dus_id}" : ""}"
  end

  def url
    "#{domain}#{link_path}"
  end

  private
    def domain
      Rails.env.development? ? "http://lvh.me:#{port}" : "https://www.downundersports.com"
    end

    def port
      ENV['LOCAL_PORT'] || '3100'
    end
end
