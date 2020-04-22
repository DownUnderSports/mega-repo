# encoding: utf-8
# frozen_string_literal: true

class School < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================
  attribute :reassign_athletes, :text

  def secret_columns
    %w[ reassign_athletes ]
  end

  # == Extensions ===========================================================

  # == Relationships ========================================================
  # belongs_to :address, inverse_of: :schools
  has_many :athletes, inverse_of: :school
  has_many :users, through: :athletes

  def self.verified_address(old_id, new_id)
    where(address_id: old_id).each do |sch|
      if ex = find_by(address_id: new_id, name: sch.name)
        sch.athletes.update(school: ex)
        sch.destroy
      else
        sch.address = Address.find(new_id)
        sch.save
      end
    end
  end

  def self.wrong_school
    @wrong_school ||= find_by(pid: 'ISWRONGSCHOOL')
  end

  # def autosave_associated_records_for_address
  #   Address.autosave_belongs_to_model self, address
  #   true
  # end

  # == Validations ==========================================================
  validates :pid,
    presence: true,
    uniqueness: true

  validates :name,
    presence: true,
    uniqueness: { scope: :address_id }

  validates :allowed, :allowed_home, :closed,
    inclusion: {
      in: [true, false],
      message: 'must be true or false'
    }

  # == Scopes ===============================================================
  default_scope { default_order(:id) }

  # == Callbacks ============================================================
  before_validation :format_fields

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.boolean_columns
    [ :allowed, :allowed_home, :closed ]
  end

  def self.is_custom?(str)
    str =~ /^(0*[A-Z]{2,}[0-9\-]+[A-Z]+|CSTM)/i
  end

  def self.custom_pid(address, name)
    address.presence && name.presence && "#{address.state_abbr}#{address.zip}#{name_abbr(name)}".pid_format
  end

  def self.name_abbr(name)
    name.to_s.strip.split(' ').map(&:first).join
  end

  def self.import_from_transfer_id(txfr_id)
    data = {}.with_indifferent_access
    result = fetch_from_legacy_data("/schools/#{txfr_id}.json")
    school = nil

    if result.present? && result['id'].present?
      result["pid"] = result["pid"].presence&.sub(/^(PID\|?)*0*/, '')&.pid_format
      school = result["pid"].presence && School.find_by(pid: result["pid"].to_s)
      data[:school_pid] = result['pid']
      if !school
        data[:school_name] = result['name']
        result['address'].each do |k, v|
          data["school_#{k}"] = v
        end
      end
    end

    if !school && data[:school_street].present?
      sch_addr = nil
      set_sch_address = ->() {
        unless sch_addr&.id
          sch_addr = sch_addr&.find_variant_by_value&.address || Address.find_or_initialize_by(
            street: data[:school_street],
            street_2: data[:school_street_2],
            city: data[:school_city],
            state: State.find_by_value(data[:school_state_abbr]),
            zip: data[:school_zip]
          )
          if (data[:school_name].to_s.upcase == "HOME SCHOOL PLACEHOLDER") && (data[:school_city].to_s.upcase == "FAKE")
            sch_addr.verified = true
            sch_addr.rejected = true
            sch_addr.keep_verified = true
          end
        end
      }

      2.times { sleep(rand * 5); set_sch_address.call }
      retries = 0
      begin
        unless sch_addr.id
          Address::ValidateBatchJob.perform_now
          sch_addr.batch_processing = true
          sch_addr.save!
          Address::ValidateBatchJob.perform_now
          sch_addr = sch_addr.find_variant_by_value&.reload&.address
        end
      rescue
        raise if (retries += 1) > 3
        sleep(rand * 5);
        set_sch_address.call
        retry
      end

      og_pid = pid = data[:school_pid].to_s.sub(/^0+/, '').presence&.pid_format

      if !pid || School.is_custom?(data[:school_pid].to_s)
        pid = School.custom_pid(sch_addr, data[:school_name])
        school = School.find_by(pid: pid)
      end

      school ||= (sch_addr && School.find_by(address: sch_addr, name: data[:school_name].titleize)) || School.create!(
        pid: pid,
        name: data[:school_name],
        address: sch_addr,
        allowed: Boolean.parse(result['allowed']),
        allowed_home: Boolean.parse(result['allowed_home']),
        closed: Boolean.parse(result['closed'])
      )
    end

    school
  end

  # == Boolean Methods ======================================================
  def is_custom?
    self.class.is_custom?(pid.to_s)
  end

  # == Instance Methods =====================================================
  def display_title
    "#{name} (#{address&.to_s(:city)})"
  end

  def reassign_athletes
    ''
  end

  def reassign_athletes=(value)
    self.class.transaction do
      school_id = School.find_by(pid: value.to_s.pid_format).id
      athletes.update_all(school_id: school_id)
      coaches.update_all(school_id: school_id)
    end
  rescue
    errors.add(:reassign_athletes, 'School Not Found - Enter a valid PID')
    throw :abort
  end

  private
    def format_fields
      format_pid
      format_name
      true
    end

    def format_name
      self.name = name.presence&.titleize&.strip
    end

    def format_pid
      if is_custom?
        self.pid = custom_pid
      else
        self.pid = pid.presence&.pid_format || custom_pid
      end
    end

    def custom_pid
      self.class.custom_pid(self.address, self.name)
    end

    def name_abbr
      self.class.name_abbr(self.name)
    end

  set_audit_methods!
end

ValidatedAddresses
