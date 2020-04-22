# encoding: utf-8
# frozen_string_literal: true

class State < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :addresses, inverse_of: :state
  has_many :teams, inverse_of: :state

  # == Validations ==========================================================
  validates :abbr, :full,
    presence: true,
    uniqueness: true

  validates :is_foreign,
    inclusion: {
      in: [true, false],
      message: 'must be true or false'
    }
  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.cached_values
    @@cached_values ||= {}
  end

  def self.clear_cache
    @@cached_values = {}
  end

  def self.find_by_col(val)
    case true
    when val.is_a?(Integer) || val.to_i.to_s == val
      :id
    when val.length == 2
      :abbr
    else
      :full
    end
  end

  def self.find_by_value(val)
    return val if val.is_a?(State)

    val_key = (val ||= "#{val}")
    return cached_values[val_key] if cached_values[val_key].present?

    type = find_by_col(val)
    case type
    when :abbr
      val.upcase!
    when :full
      val = val.titleize.gsub(/of/i, 'of')
    end

    cached_values[val_key] = (cached_values[val] ||= find_by(type => val))
  end

  def self.map_to_abbr_hash
    all.pluck(:id, :abbr).reduce({}) {|list, state| list[state[0]] = state[1]; list}
  end

  def self.boolean_columns
    [ :is_foreign ]
  end

  def self.const_missing(name)
    const_set name, self[name] || super
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

  set_audit_methods!
end
