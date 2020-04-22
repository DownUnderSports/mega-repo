# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  class Variant < ApplicationRecord
    # == Constants ============================================================
    ADDRESS_KEYS = [ :street, :street_2, :street_3, :city, :state_abbr, :province, :zip, :country ]

    HAS_CANDIDATE_IDS_SQL = 'array_upper(candidate_ids, 1) IS NOT NULL'

    SERIALIZE_DELIM = '!@!'

    SELECTION_SQL = <<-SQL
      states.abbr = ?
      AND
      #{HAS_CANDIDATE_IDS_SQL}
    SQL

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    # belongs_to :address, inverse_of: :variants, autosave: true

    # == Validations ==========================================================
    validates :value, presence: true,
                    format: { with: /.+(#{SERIALIZE_DELIM}.*)+/ },
                    uniqueness: true

    # == Scopes ===============================================================
    scope :needs_selection, ->(state_abbr) do
      unscoped.references(:state).where(SELECTION_SQL, state_abbr.upcase)
    end

    scope :state_list, -> do
      joins(:address).references(:address).distinct.
      select('addresses.state_id').where(has_candidate_ids_sql)
    end

    scope :with_candidates, -> { where HAS_CANDIDATE_IDS_SQL }
    scope :without_candidates, -> { where.not HAS_CANDIDATE_IDS_SQL }

    # == Callbacks ============================================================
    before_validation :set_value

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.from_address(address)
      find_or_initialize_by(
        address: address,
        value: serialize(address.as_json.with_indifferent_access)
      )
    end

    def self.deserialize(value)
      attrs = {}.with_indifferent_access
      split_up = value.to_s.split(SERIALIZE_DELIM, -1)
      return false unless split_up.size == ADDRESS_KEYS.size

      ADDRESS_KEYS.each_with_index do |col, i|
        attrs[col] = split_up[i]
      end
      attrs
    end

    def self.has_candidate_ids_sql
      HAS_CANDIDATE_IDS_SQL
    end

    def self.serialize(address, skip_country = false)
      ADDRESS_KEYS.
      map do |col|
        if skip_country && (col == :country)
          nil
        else
          address[col].presence
        end
      end.
      join(SERIALIZE_DELIM)
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def candidates
      Address.where(id: candidate_ids)
    end

    def deserialize
      self.class.deserialize(value)
    end

    def set_value
      self.value = (deserialize ? value : self.class.serialize(address.normalize))
    end

  end
end

ValidatedAddresses
