# encoding: utf-8
# frozen_string_literal: true

class Payment < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.payments"

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :user, touch: true
  belongs_to :shirt_order, optional: true, touch: true
  belongs_to :remittance, foreign_key: 'remit_number', primary_key: 'remit_number', inverse_of: :payments, optional: true, touch: true

  has_one :join_terms, dependent: :destroy
  has_one :terms, through: :join_terms

  has_many :items
  has_many :traveler_items
  has_many :basic_items

  accepts_nested_attributes_for :items, reject_if: :all_blank

  # == Validations ==========================================================

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  scope :successful, -> { where(successful: true) }
  scope :pending, -> { successful.where(status: 'PENDING REVIEW') }
  scope :decided, -> { successful.where.not(status: 'PENDING REVIEW').or(successful.where(status: nil)) }
  scope :failed, -> { where(successful: false) }
  scope :auth_net, -> { where(gateway_type: 'authorize.net') }
  scope :brain_tree, -> { where(gateway_type: 'braintree') }

  # == Callbacks ============================================================
  after_commit :set_terms, on: [ :create ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.import_from_csv(csv)
    csv = CSV.parse(csv.gsub("\n\n", "\n"), headers: true)
    csv.each do |r|
      if r['dus_id'] =~ /^[A-Z]{3}\-[A-Z]{3}$/
        create_from_lookup(transaction_id: r['transaction_id'], user: r['dus_id'])
      end
    end
  end

  def self.create_from_lookup(transaction_id:, user:)
    # if id.blank? || user.blank?
    #   id_was, id = [id.presence, nil]
    #   while id.blank?
    #     puts "Enter Transaction ID #{id_was.present? ? '(Enter to Use Current)' : ''}"
    #     value = gets
    #     if value == "\n"
    #       id, id_was = [id_was, nil]
    #     else
    #       id = value.strip
    #     end
    #   end
    #
    #   user = id_was.presence
    #
    #   while user.blank?
    #     puts "Enter User ID"
    #     user = gets.strip.presence
    #   end
    # end

    pmt = nil

    transaction do
      user = User[user]

      raise "Cannot Modify Previous Year" unless user.payable?

      unless user.traveler
        user.create_traveler!(team: user.team)
        user.traveler.base_debits!
      end

      pmt = Payment.find_by(transaction_id: transaction_id) ||
        user.payments.create!(
          **(
            Payment::Transaction::AuthNet::Lookup.
              run(transaction_id, environment: :production)
          )
        )

      if pmt.successful && !pmt.items.present?
        pmt.items << Payment::Item.new(
          traveler: user.traveler,
          amount: pmt.amount,
          price: pmt.amount,
          name: 'Account Payment',
          description: "#{pmt.amount < 0 ? 'Refunded Payment' : 'Account Payment'} for #{user.print_names}",
          created_at: pmt.created_at
        )
      end
    end

    pmt
  end

  def self.create_transfer(**opts)
    create(Payment::Transaction::Transfer.new(**opts).payment_attributes)
  end

  def self.create_chargeback(**opts)
    create(Payment::Transaction::Chargeback.new(**opts).payment_attributes)
  end

  def self.default_print
    %i[
      id
      user_id
      successful
      amount
      gateway_type
      remit_number
      category
      transaction_id
      shirt_order_id
      created_at
      updated_at
    ]
  end

  def self.find_category(pmt_type)
    case pmt_type.to_s.underscore
    when 'ach'
      return 'ACH'
    when /check/
      return 'Check'
    when /american/
      return 'Amex'
    when /master/
      return 'MasterCard'
    else
      return (pmt_type || 'Card').underscore.titleize
    end
  end

  def self.overpayment(user, amount = nil)
    u = User[user]

    raise "Invalid" unless amount.presence || u.balance < 0

    amount ||= -u.balance

    Payment.create_transfer is_refund: true, amount: amount, from: u
  end

  # == Boolean Methods ======================================================

  def pending?
    self.status == "PENDING REVIEW"
  end

  # == Instance Methods =====================================================
  def refund!(disputed = false)
    self.status = disputed ? 'disputed.' : 'refunded.'
    self.successful = false
    save!
    items.reload.each do |i|
      ni = i.dup
      ni.name = disputed ? 'Disputed Payment' : 'Returned Payment'
      ni.description = disputed ? 'Payment Disputed by Cardholder' : 'Payment Refunded'
      ni.amount *= -1
      ni.price *= -1
      ni.save!
    end
    true
  end

  def accept!
    if pending?
      self.status = "accepted"
      self.risk ||= {}
      self.risk["decision"] = "accepted"
      save!
    end
  end

  def dispute!
    refund! true
  end

  def void!
    self.status = 'voided.'
    self.successful = false
    save!
    items.destroy_all
    true
  end

  def chargeback!(amount: nil, reference_id: nil, created_at: nil)
    self.class.create_chargeback(
      payment: self,
      amount: amount,
      reference_id: reference_id,
      created_at: created_at || Time.zone.now
    )
  end

  def set_terms
    create_join_terms!(terms: Terms.latest)
  end

  set_audit_methods!
end
