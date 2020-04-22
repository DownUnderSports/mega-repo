# encoding: utf-8
# frozen_string_literal: true

class Address < ApplicationRecord
  # Rails.application.eager_load!
  # == Constants ============================================================

  # == Attributes ===========================================================
  def batch_processing
    @batch_processing
  end

  def batch_processing=(value)
    @batch_processing = Boolean.strict_parse(value)
  end

  def keep_verified
    @keep_verified
  end

  def keep_verified=(value)
    @keep_verified = Boolean.strict_parse(value)
  end

  def in_create_loop
    @in_create_loop
  end

  def in_create_loop=(value)
    @in_create_loop = Boolean.strict_parse(value)
  end

  # == Extensions ===========================================================
  def serializable_hash(*)
    super.tap do |h|
      h['state_abbr'] = self.state_abbr
    end
  end

  # == Relationships ========================================================
  belongs_to :state, optional: true, inverse_of: :addresses
  belongs_to :student_list, optional: true, inverse_of: :addresses

  # has_many :flight_airports, inverse_of: :address, autosave: true, dependent: :nullify
  # has_many :schools, inverse_of: nil, autosave: true, dependent: :nullify
  # has_many :users, inverse_of: :address, autosave: true, dependent: :nullify
  # has_many :traveler_hotels, class_name: 'Traveler::Hotel', inverse_of: :address, autosave: true, dependent: :nullify
  # has_many :variants, inverse_of: :address, autosave: true, dependent: :destroy

  # == Validations ==========================================================
  validates_presence_of :street, :zip
  # validates_uniqueness_of :street, scope: [:street_2, :city, :state, :zip, :root_id]
  validate :state_and_city_or_province_and_country_exists

  # == Scopes ===============================================================
  default_scope { includes(:state) }

  scope :state_list, -> { unscoped.distinct.select(:state_id).joins(:variants).where(Address::Variant.has_candidate_ids_sql) }


  # == Callbacks ============================================================
  after_commit :validate_address
  before_validation :normalize
  after_validation :build_variant
  # before_update :set_verified

  # == Boolean Class Methods ================================================
  def self.is_set_to_batch?
    Boolean.parse (Rails.redis.get 'address:batching')
  end

  # == Class Methods ========================================================

  def self.run_autosave_belongs_to_model(model, tmp_address, association_name = :address)
    unless tmp_address.present?
      model.__send__(:"#{association_name}=", nil)
      return true
    end

    # rms = tmp_address.returned_mails.to_a
    if tmp_address.new_record?
      tmp_address = merge_or_create(tmp_address, true)
    elsif existing = find_by(id: tmp_address.id)
      if changed(tmp_address, existing)
        tmp_address = merge_or_create(tmp_address)
      end
    end
    # tmp_address.returned_mails ||= []
    # tmp_address.returned_mails |= rms
    tmp_address.save

    model.__send__ :"#{association_name}=", tmp_address
  end

  def self.run_autosave_other_models(model, addresses)
    return true unless addresses.present?
    addresses_list = []

    addresses.each do |address|
      if address._destroy
        model.addresses.delete(address)
        next
      end
      # rms = address.returned_mails.to_a
      # puts "\n\n\n\n\n\n", rms, "\n\n\n\n\n\n"

      if address.new_record?
        puts 'NEW RECORD'
        address = merge_or_create(address)
      else
        if existing = find_by(id: address.id)
          if changed(address, existing)
            model.addresses.delete(address)
            address = merge_or_create(address)
          elsif address.category != existing.category
            address.save
          end
        else
          model.addresses.delete(address)
          next
        end
      end

      # address.returned_mails ||= []

      # address.returned_mails |= rms

      address.save

      addresses_list << address
    end

    addresses_list.each do |address|
      unless model.addresses.any? {|addr| addr.id == address.id}
        begin
          model.addresses << address
        rescue
          puts $!.message
          puts $!.backtrace.first(100)
        end
      end
    end
  end

  def self.changed(address_1, address_2)
    normalize(address_1).except(:category) != normalize(address_2).except(:category)
  end

  def self.default_print
    [
      :id,
      :inline,
      :state_abbr,
      :dst,
      :tz_offset,
      :is_foreign,
      :student_list_id,
      :rejected,
      :verified,
    ]
  end

  def self.find_normalized(address)
    address = address.with_indifferent_access if address.is_a?(Hash)
    normalized = normalize(address)

    found = get_normalized(normalized)
    variant = found.find_variant_by_value
    variant ? variant.address : found
  end

  def self.get_normalized(attrs)
    find_or_initialize_by(
      attrs.
      except(*(attrs[:is_foreign] ? META_FIELDS : [:country, *META_FIELDS]))
    )
  end

  def self.merge_or_create(address, preserve = false)
    address = address.with_indifferent_access if address.is_a?(Hash)
    normalized = normalize(address)

    found = get_normalized(normalized)

    found.verified ||= normalized[:verified] if preserve

    variant = found.find_variant_by_value

    if variant
      found = variant.address
      if found.rejected && (normalized[:state] != found.state)
        found.update_columns(normalized.except(:state).merge(state_id: normalized[:state]&.id, rejected: false, verified: false))
      end
    else
      found.build_variant(found.persisted?)
    end


    if preserve
      if found.persisted? && META_FIELDS.any? {|k| found[k] != normalized[k]}
        found.update_columns(
          **META_FIELDS.map {|k| [k, normalized[k]]}.to_h
        )
      end

      META_FIELDS.each do |k|
        found[k] = normalized[k]
      end
    end

    found.save
    found
  end

  def self.new(attrs = {})
    return super(attrs) if attrs.blank?
    attrs = attrs.attributes if attrs.is_a?(ActiveRecord::Base)
    super(attrs.with_indifferent_access.merge(normalize(attrs.with_indifferent_access)))
  end

  def self.normal_zip(zip)
    return nil unless zip.present?
    zip = zip.gsub(/\D/, '')
    return "0#{zip}" if zip.length < 5
    return zip.insert(-5, '-') if zip.length > 5
    zip
  end

  def self.normalize(address)
    address = address.with_indifferent_access if address.is_a?(Hash)

    is_foreign = Boolean.strict_parse(address['is_foreign'])

    if address['state_or_province'].present?
      address[is_foreign ? 'province' : 'state'] = address['state_or_province']
    end

    {
      is_foreign: is_foreign,
      street: titleize(address['street']),
      street_2: titleize(address['street_2']),
      street_3: titleize(address['street_3']),
      city: titleize(address['city']),
      state: State.find_by_value(address['state_id'] || address['state'] || address['state_abbr']),
      province: titleize(address['province']),
      zip: (is_foreign ? address['zip'] : normal_zip(address['zip'])),
      country: is_foreign ? address['country'].presence&.upcase : 'USA',
      dst: Boolean.strict_parse(address['dst']),
      tz_offset: normalize_tz_offset(address['tz_offset'].to_i),
      student_list_id: address['student_list_id'].presence,
      rejected: Boolean.strict_parse(address['rejected']),
      verified: Boolean.strict_parse(address['verified']),
      # keep_verified: Boolean.parse(address['keep_verified']),
    }
  end

  def self.return_or_create_id(address, preserve = false)
    address = address.with_indifferent_access
    batch = address[:batch]
    address = new normalize(address)
    address.batch_processing = batch
    merge_or_create(address, preserve).id
  end

  def self.set_to_batch
    Boolean.parse (Rails.redis.incr 'address:batching')
  end

  def self.set_to_normal
    v = Rails.redis.get 'address:batching'

    if v.to_i < 1
      Rails.redis.set 'address:batching', 0
      return false
    end

    Boolean.parse (Rails.redis.decr 'address:batching')
  end


  def self.process_batches
    not_ready = Boolean.parse(Rails.redis.get('address:ready')) rescue false
    return if not_ready

    begin
      Rails.redis.incr 'address:ready'
      n=0
      base = where(verified: false)
      while Boolean.parse base.count
        Address::Validator.validate_addresses(base.limit(100))
        sleep(5)

        # where(verified: false).left_outer_joins(:candidates).where(candidates_addresses: { id: nil }).find_in_batches(batch_size: 100) do |addresses|
        #   puts "Validator Called Batch #{n += 1}"
        #   Address::Validator.validate_addresses(addresses)
        #   sleep(5)
        # end
      end
    rescue
      puts $!.message
      puts $!.backtrace.first(100)
    ensure
      Rails.redis.set 'address:ready', 0
    end
  end

  def self.needs_selection_by_state(state_abbr)
    needs_selection
  end

  def self.titleize(str)
     (str.presence || '').strip.titleize.gsub(/(?<=^|\s)(?!cr|cl|dr|ln|pl|rd|st)([a-z]{2})(?=\s|$)/i) {|str| str.upcase }.presence
  end

  def self.verified_models
    @@verified_models ||= []
  end

  def self.add_verified_model(klass)
    @@verified_models << klass unless @@verified_models.include?(klass)
  end

  # == Boolean Methods ======================================================
  def allow_autosave_preserve?
    !(existing = self.class.find_by(id: self.id)) ||
    normalize.except(*META_FIELDS) ==
      existing.
      __send__(:normalize).except(*META_FIELDS)
  end

  def is_foreign?
    !!self.is_foreign
  end

  def has_variant?
    variants.size > 0
  end

  def has_other_variant?
    variants.where.not(value: serialized).size > 0
  end

  def is_a_candidate?
    potential_candidates.size > 0
  end

  def is_po_box?(value = nil)
    if !value && street_2.presence && is_po_box?(street_2)
      value = street_2
      self.street_2 = street.presence
      self.street = value
      return true
    end
    !!((value || street).to_s =~ /p\.?o\.?\s+box/i)
  end

  # def readonly?
  #   !new_record? && values_changed?
  # end

  def rejected?
    !!self.rejected
  end

  def verified?
    !!self.verified
  end

  # == Instance Methods =====================================================
  def build_variant(should_save = false)
    unless has_variant?
      variant = find_variant_by_value || variants.build(value: serialized)
      return variant.save if should_save
    end
    true
  end

  def country_if_foreign(inline = false)
    is_foreign ? "#{inline ? ', ': "\n"}#{country}" : nil
  end

  def find_variant_by_value
    if is_foreign
      Address::Variant.find_by(value: serialized)
    else
      Address::Variant.find_by(value: [serialized, serialized_no_country].uniq)
    end
  end

  def flight_card
    to_s(:flight_card)
  end

  def found_verified(address)
    if address.id == id
      update_columns(verified: true)
    else
      begin
        v = find_variant_by_value
        if v
          v.update_columns(address_id: address.id)
        else
          address.variants.build(value: serialized)
        end
      rescue
      end

      variants.reload

      begin
        User.verified_address id, address.id
      rescue
      end

      begin
        School.verified_address id, address.id
      rescue
      end

      begin
        Flight::Airport.verified_address id, address.id
      rescue
      end

      begin
        Traveler::Hotel.verified_address id, address.id
      rescue
      end

      if has_variant?
        update_columns(verified: true)
      else
        begin
          destroy
        rescue
          begin
            delete
          rescue
          end
        end
      end
    end
  end

  def inline
    to_s(:inline)
  end

  def label
    to_s
  end

  def normalize
    self.attributes = self.attributes.deep_symbolize_keys.merge(self.class.normalize(self.attributes.with_indifferent_access))
  end

  def potential_candidates
    Address::Variant.where('? <@ candidate_ids')
  end

  def print_if_value(val, inline = false)
    val.present? ? "#{val}#{inline ? ', ': "\n"}" : ''
  end

  def province_or_state_abbr
    province.presence || state_abbr.presence
  end

  def serialized
    Address::Variant.serialize(self.as_json.with_indifferent_access)
  end

  def serialized_no_country
    Address::Variant.serialize(self.as_json.with_indifferent_access, true)
  end

  def state_abbr
    state&.abbr
  end

  def to_s(formatting = :default)
    if is_foreign && self.class::Countries.const_defined?(country.gsub(' ', '_').classify.upcase, false)
      self.class::Countries.const_get(country.classify.upcase).new(self.attributes).to_s(formatting)
    else
      p_box = !!is_po_box?
      case formatting
      when :city
        "#{city}, #{porsa}"
      when :postcard
        "#{"#{street}, #{piv(p_box ? nil : street_2, true)}#{piv(p_box ? nil : street_3, true)}".sub(/,\s+$/, '')}\n#{city}, #{porsa} #{zip}"
      when :flight_card
        "#{street}, #{piv(street_2, true)}#{piv(street_3, true)}#{city} #{porsa} #{zip}"
      when :inline
        "#{street}, #{piv(street_2, true)}#{piv(street_3, true)}#{city}, #{porsa}, #{zip}#{cif(true)}"
      when :streets
        "#{street}, #{piv(street_2, true)}#{piv(street_3, true)}".sub(/,\s+$/, '')
      else
        "#{street}\n#{piv(street_2)}#{piv(street_3)}#{city}, #{porsa} #{zip}#{cif}"
      end
    end
  rescue
    super()
  end

  def to_shipping(include_state_id = false)
    if is_foreign
      {
        street: street,
        street_2: street_2,
        street_3: street_3,
        city: city,
        province: province,
        zip: zip,
        country: country
      }
    else
      {
        street: street,
        street_2: street_2,
        city: city,
        state: state.abbr,
        zip: zip
      }.merge(include_state_id ? {state_id: state_id} : {})
    end
  end

  def unrejected
    self.rejected? ? nil : self
  end

  private
    def create_or_update(*args, &block)
      _raise_readonly_record_error if readonly?
      return false if destroyed?

      result = false

      if !new_record? && allow_autosave_preserve?
        begin
          result = _update_record(*args, &block)
        rescue ActiveRecord::InvalidForeignKey
          if Rails.env.development?
            puts self.inline, self.variants.map(&:value)
            puts args, block
            puts $!.backtrace
          end
          raise
        end

      else
        found = self.class.find_or_initialize_by(
          self.class.
            normalize(self).
            except(:id, *META_FIELDS)
        )

        if variant = found.find_variant_by_value
          found = variant.address
        end

        f_a = found.indifferent_attributes.except(*META_FIELDS)
        s_a = indifferent_attributes.except(*META_FIELDS)

        if found.persisted?
          new_cols = {}
          %i[
            country
            tz_offset
            dst
          ].each do |k|
            unless (f_a[k] == s_a[k])
              new_cols[k] = s_a[k]
            end
          end

          new_cols[:tz_offset] = normalize_tz_offset(new_cols[:tz_offset]) if new_cols[:tz_offset].present?

          found.update_columns(new_cols) if new_cols.present?
        else
          if f_a == s_a
            return _create_record(&block) != false
          end

          found = self.class.new(found.attributes)
          found.in_create_loop = true

          if new_record?
            META_FIELDS.each do |k|
              found[k] = self[k]
            end
          end
        end

        result = found.persisted? || found.save

        found.reload if result

        found.attributes.each do |k, v|
          self[k] = v
        end

        self.reload if result

      end

      result != false
    end

    def piv(*args)
      print_if_value *args
    end

    def porsa
      province_or_state_abbr
    end

    def cif(*args)
      country_if_foreign *args
    end

    def set_verified
      self.verified = false if !keep_verified && values_changed?
      true
    end

    def values_changed?
      self.street_changed? \
      || self.street_2_changed? \
      || self.street_3_changed? \
      || self.city_changed? \
      || self.state_id_changed? \
      || self.province_changed? \
      || self.zip_changed? \
      || self.tz_offset_changed? \
      || self.dst_changed? \
      || self.country_changed?
    end

    def skip_verification
      batch_processing ||
      is_foreign? ||
      self.verified ||
      self.rejected
    end

    def validate_address
      # return found_verified(self.class.find_by(id: self.selected)) if self.selected
      return if skip_verification
      ValidateBatchJob.perform_later(self.id)
    end

    def state_and_city_or_province_and_country_exists
      if is_foreign?
        errors.add(:province, "Address Province is required for foreign addresses") if province.blank?
        if country.blank?
          errors.add(:country, "Address Country is required for foreign addresses")
        elsif COUNTRY_LIST[country].blank?
          p "\n#{country}\n"
          errors.add(:country, "Address Country not found")
        end
        return false
      else
        errors.add(:state_id, "Address State is required for US addresses") if state_id.blank?
        errors.add(:city, "Address City is required for US addresses") if city.blank?
        return false
      end
    end

  set_audit_methods!
end

ValidatedAddresses
