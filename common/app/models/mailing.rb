# encoding: utf-8
# frozen_string_literal: true

class Mailing < ApplicationRecord
  # == Constants ============================================================
  NON_DUPABLE_KEYS = Set.new(%i[ sent printed failed ])

  # == Attributes ===========================================================
  # self.table_name = "#{usable_schema_year}.mailings"
  #    user_id: :integer
  #   category: :text
  #       sent: :date
  #    printed: :boolean, required
  #    is_home: :boolean, required
  # is_foreign: :boolean, required
  #       auto: :boolean, required
  #     failed: :boolean, required
  #     street: :text, required
  #   street_2: :text
  #   street_3: :text
  #       city: :text, required
  #      state: :text, required
  #        zip: :text, required
  #    country: :text
  # created_at: :datetime, required
  # updated_at: :datetime, required
  attribute :vacant, :boolean, default: false
  attribute :bad_address, :boolean, default: false
  attribute :new_address, :json, default: -> { {} }

  # == Extensions ===========================================================

  # == Relationships ========================================================
  belongs_to :user, inverse_of: :mailings, touch: true
  before_create :check_active_year
  before_destroy :check_active_year

  # == Validations ==========================================================

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  scope :invites, -> { where(arel_table[:category].matches('invite%')) }
  scope :home_invites, -> { where(category: "invite_home") }
  scope :school_invites, -> { where(category: "invite_school") }
  scope :infokits, -> { where(category: "infokit") }
  scope :fr_packets, -> { where(category: "fundraising_packet") }
  scope :unsent, -> { where(sent: nil) }

  # == Callbacks ============================================================
  after_commit :fix_failed, on: %i[ update ]

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def switch_to_home_if_available!(addr = nil)
    addr ||= user&.main_address
    if addr
      self.is_home = true
      self.category&.sub!(/_school$/, '_home')
      self.address = addr
      self.save!
    else
      raise "No Address Found"
    end
  end

  def set_address(addr)
    addr = Address.new(addr) unless addr.is_a?(Address)
    self.is_foreign = Boolean.parse(addr.is_foreign)
    self.street = addr.street.presence
    self.street_2 = addr.street_2.presence
    self.street_3 = addr.street_3.presence
    self.city = addr.city.presence
    self.state = is_foreign ? addr.province : addr.state_abbr
    self.zip = addr.zip.presence
    self.country = is_foreign ? addr.country : 'USA'
    address
  end

  def address=(addr)
    set_address(addr)
  end

  def address
    self.street.presence && {
      is_foreign: self.is_foreign,
      street: self.street,
      street_2: self.street_2,
      street_3: self.street_3,
      city: self.city,
      state: self.state,
      zip: self.zip,
      country: self.country,
    }
  end

  def address_record
    @address_record ||= self.address && Address.find_normalized(address)
  end

  def get_addr_str(str_format = nil)
    address && Address.new(address).to_s(str_format)
  end

  def streets
    get_addr_str(:streets)
  end

  def postcard
    get_addr_str(:postcard)
  end

  def new_address=(addr)
    addr = Address.find_normalized(addr).to_shipping if addr.present?
    super
  end

  def bad_address_effects
    Mailing.where(self.address).count
  end

  def new_address_effects
    Mailing.where(failed: false, **self.address, **(self.is_home ? {user_id: self.user_id} : {})).where('sent >= ?', self.sent).count
  end

  def vacant_effects
    if self.address_record&.id
      self.address_record.schools.count + self.address_record.users.count
    else
      0
    end
  end

  private
    def fix_failed
      if self.vacant
        self.vacant = false
        Mailing.where(self.address).split_batches do |b|
          b.each do |m|
            m.update(failed: true)
            if m.category == 'invite_home' && (sa = m.user&.athlete&.school&.address)
              unless m.user.mailings.find_by(category: 'invite_school')
                n = m.dup
                n.address = sa
                n.category = 'invite_school'
                n.explicit = true
                n.is_home = false
                n.sent = nil
                n.save
              end
            end
          end
        end

        if self.address_record&.id
          self.address_record.schools.split_batches do |b|
            b.each do |sch|
              sch.update(address_id: nil)
            end
          end

          self.address_record.users.split_batches do |b|
            b.each do |u|
              u.update(address_id: nil)
            end
          end
        end
      elsif self.bad_address
        self.bad_address = false
        Mailing.where(self.address).split_batches do |b|
          b.each {|m| m.update(failed: true) }
        end

        self.address_record&.id && self.address_record.update(rejected: true)
      elsif self.new_address.present?
        na = Address.find_normalized(self.new_address)
        self.new_address = nil
        if na.valid?
          Mailing.where(failed: false, **self.address, **(self.is_home ? {user_id: self.user_id} : {})).where('sent >= ?', self.sent).split_batches do |b|
            b.each do |m|
              if m.user&.address_id == m.address_record.id
                User.find_by(id: m.user_id)&.update(address: na)
              else
                School.find_by(address_id: m.address_record.id)&.update(address: na)
              end

              m.update(failed: true)

              n = m.dup
              n.address = na
              n.save unless Mailing.find_by(user_id: n.user_id, category: n.category, **n.address)
            end
          end
        end
      end
      true
    rescue
      puts $!.message
      puts $!.backtrace
      true
    end

end
