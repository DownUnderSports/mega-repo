# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class Nationality < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    # has_many :users, inverse_of: :nationality, dependent: :nullify
    has_many :passports, inverse_of: :nation, foreign_key: :code, primary_key: :code

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.find_by_nationality(v)
      return nil unless v.to_s.gsub(/[^A-Za-z]/, '').present?

      self.where("nationality ilike ?", v.to_s.upcase.gsub(/[^A-Z0-9]/, '%')).take
    end

    def self.get_birth_country(v)
      return v if v.is_a?(self)

      v = v.to_s.strip

      return nil unless v.present?

      res = v =~ /\([A-Za-z]+\)/ \
        ? find_by(code: v.upcase.split("(").last.gsub(/[^A-Z]/, ''))
        : get(v)

      res&.birth_country
    end

    def self.get(v)
      return v if v.is_a?(self)

      v = v.to_s.strip

      return nil unless v.present?


      return find(v) if v =~ /^\s*[0-9]+\s*$/

      v = v.gsub(/[^A-Za-z]/, ' ')

      case v
      when /^\s*[A-Za-z]{3}\s*$/
        find_by(code: v.strip.upcase)
      when /^[A-Z ]+$/
        where("nationality ilike ?", v.gsub(/\s+/, '%')).order(:nationality).take
      else
        where("country ilike ?", v.gsub(/\s+/, '%')).order(:country).take
      end
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def birth_country
      "#{self.code == 'USA' ? 'USA' : self.country} (#{self.code})"
    end

  end
end
