# encoding: utf-8
# frozen_string_literal: true

# ThankYouTicket description
class ThankYouTicket < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  attribute :uuid, :text

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :user, inverse_of: :thank_you_tickets

  # == Validations ==========================================================
  validates_presence_of :name, :email, :phone, :mailing_address, if: :submitted?

  # == Scopes ===============================================================
  scope :available, -> { where(name: nil) }

  # == Callbacks ============================================================
  after_commit :reload if -> { uuid.nil? }

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================
  def submitted?
    name&.present? \
    || email&.present? \
    || phone&.present? \
    || mailing_address&.present?
  end

  # == Instance Methods =====================================================
  def as_json(options = nil)
    host = options.delete(:host) if options.is_a?(Hash) && options[:host]
    reload if persisted? && uuid.nil?
    super(options).tap do |h|
      h[:link] = link_path
      h[:qr_code] = qr_code_path(host)
    end
  end

  def qr_code_path(host = nil)
    "/api/qr_codes/#{Base64.strict_encode64(url(host))}"
  end

  def link_path
    "/redeem_ticket/#{uuid}#{user ? "?dus_id=#{user.dus_id}" : ""}"
  end

  def url(host = nil)
    "#{host || domain}#{link_path}"
  end

  def qr_code_url(host = nil)
    "#{host || domain}#{qr_code_path(host)}"
  end

  private
    def domain
      Rails.env.development? ? "http://lvh.me:#{port}" : "https://www.downundersports.com"
    end

    def port
      ENV['LOCAL_PORT'] || '3100'
    end
end
