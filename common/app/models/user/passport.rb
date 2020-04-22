# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class Passport < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    self.inheritance_column = nil

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, touch: true
    belongs_to :checker, class_name: 'User', optional: true
    belongs_to :second_checker, class_name: 'User', optional: true
    belongs_to :nation, class_name: 'User::Nationality', foreign_key: :code, primary_key: :code, optional: true, inverse_of: :passports

    has_one :travel_preparation, through: :user, inverse_of: :passport, autosave: true

    has_one_attached :image

    has_many_attached :eta_proofs

    delegate :dus_id, to: :user

    delegate_missing_to :get_or_create_travel_preparation

    # == Validations ==========================================================
    before_save :save_travel_preparation

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :normalize

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.default_print
      %i[
        id
        user_id
        checker_id
        second_checker_id
        type
        code
        given_names
        surname
      ]
    end

    def self.new(attrs = {})
      return super(attrs) if attrs.blank?
      attrs = attrs.attributes if attrs.is_a?(ActiveRecord::Base)
      super(
        attrs.
          with_indifferent_access.
          merge(normalize(attrs.with_indifferent_access))
      )
    end

    def self.strip_special(v)
      ActiveSupport::Inflector.transliterate(v.to_s).strip
    end

    def self.normalize(passport)
      passport = passport.with_indifferent_access if passport.is_a?(Hash)

      {
        type: passport['type'].to_s.upcase.gsub(/[^A-Z]/, '').first.presence,
        code: passport['code'].to_s.upcase.gsub(/[^A-Z]/, '').slice(0,3).presence,
        nationality: strip_special(passport['nationality']).upcase.gsub(/[^A-Z ]/, '').presence,
        authority: strip_special(passport['authority']).gsub(/\s+/, ' ').titleize.gsub(/ (Of|The) /, &:downcase).presence,
        number: passport['number'].to_s.strip.upcase.presence,
        surname: passport['surname'].to_s.strip.upcase.presence,
        given_names: passport['given_names'].to_s.strip.upcase.presence,
        sex: passport['sex'].to_s.upcase.gsub(/[^A-Z]/, '').first.presence,
        birthplace: passport['birthplace'].to_s.upcase.presence,
        birth_date: passport['birth_date'].to_s.presence,
        issued_date: passport['issued_date'].to_s.presence,
        expiration_date: passport['expiration_date'].to_s.presence,
        country_of_birth: User::Nationality.get_birth_country(strip_special(passport['country_of_birth']))
      }
    end

    # == Boolean Methods ======================================================
    def values_changed?
      self.type_changed? \
      || self.code_changed? \
      || self.nationality_changed? \
      || self.authority_changed? \
      || self.number_changed? \
      || self.surname_changed? \
      || self.given_names_changed? \
      || self.sex_changed? \
      || self.birthplace_changed? \
      || self.birth_date_changed? \
      || self.issued_date_changed? \
      || self.expiration_date_changed? \
      || self.country_of_birth_changed?
    end

    # == Instance Methods =====================================================
    def eta_values
      ntl = User::Nationality.find_by_nationality(self.nationality)
      {
        "APPLICANT_ALIAS"          => self.has_aliases,
        "CITIZEN_COUNTRY_1"        => "#{
                                        User::Nationality.get_birth_country(self.citizenships_array[0].presence) \
                                        || self.citizenships_array[0].presence
                                      }",
        "CITIZEN_COUNTRY_2"        => "#{
                                        User::Nationality.get_birth_country(self.citizenships_array[1].presence) \
                                        || self.citizenships_array[1].presence
                                      }",
        "CITIZEN_COUNTRY_3"        => "#{
                                        User::Nationality.get_birth_country(self.citizenships_array[2].presence) \
                                        || self.citizenships_array[2].presence
                                      }",
        "CITIZEN_OTH_COUNTRIES"    => self.has_multiple_citizenships,
        "COUNTRY_OF_BIRTH"         => "#{
                                        User::Nationality.get_birth_country(self.country_of_birth.presence) \
                                        || (self.birthplace =~ /U\.?S\.?\.A/ ? 'USA (USA)' : nil)
                                      }",
        "CRIMINAL_CONVICTION"      => self.has_convictions,
        "DATE_OF_BIRTH"            => "#{ self.birth_date&.strftime("%d%b%Y")&.upcase }",
        "DATE_OF_ISSUE"            => "#{ self.issued_date&.strftime("%d%b%y")&.upcase }",
        "EMAIL"                    => "#{ 'mail@downundersports.com' || self.user.main_email }",
        "EXPIRATION_DATE"          => "#{ self.expiration_date&.strftime("%d%b%y")&.upcase }",
        "GIVEN_NAMES"              => "#{ self.given_names }",
        "HOME_ADDRESS"             => "#{ self.user.main_address.to_s }",
        "HOME_PHONE_AREA"          => "#{ self.split_phone[1] }",
        "HOME_PHONE_COUNTRYCODE"   => "#{ self.split_phone[0].sub(/\+/, '') }",
        "HOME_PHONE_NUMBER"        => "#{ self.split_phone[2] }#{ self.split_phone[3] }",
        "ISSUING_AUTHORITY"        => "#{ self.authority }",
        "ISSUING_COUNTRY"          => User::Nationality.get_birth_country(self.code) || "#{ self.code } (#{ self.code })",
        "LAST_NAME"                => "#{ self.surname }",
        "NATIONALITY"              => "#{
                                        User::Nationality.find_by_nationality(self.nationality)&.birth_country \
                                        || "#{ self.nationality }"
                                      }",
        "NATIONAL_IDENTITY_NUMBER" => "",
        "PASSPORT_NUMBER"          => "#{ self.number }",
        "SEX"                      => "#{ self.sex }",
        "TYPE_OF_TRAVEL"           => "T",
      }
    end

    def full_name
      "#{self.given_names} #{self.surname}"
    end

    def normalize
      self.attributes =
        self.attributes.
          deep_symbolize_keys.
          merge(
            self.class.normalize(self.attributes.with_indifferent_access)
          )

      self.checker_id = self.second_checker_id = nil if values_changed?
    end

    def normalize!
      normalize
      save!
    end

    def verify!(params)
      normalize!

      check_against = self.class.new(params)

      changed = []
      %w[
        type
        code
        nationality
        authority
        number
        surname
        given_names
        sex
        birthplace
        birth_date
        issued_date
        expiration_date
        country_of_birth
      ].each do |k|
        if check_against.__send__(k) != self.__send__(k)
          changed << k.titleize
          self.__send__("#{k}=", check_against.__send__(k))
        end
      end
      if changed.present?
        self.checker = nil
        self.second_checker = nil
        self.save!
        raise "Not Matched: #{changed.join(', ')}"
      end
    end

    def split_phone
      ['1', '435', '753', '4732'] \
      || (self.user.main_phone.presence || '--').split('-').map(&:to_s).map(&:strip).presence&.unshift('1')
    end

    def get_or_create_travel_preparation
      user&.get_or_create_travel_preparation
    end

    def save_travel_preparation
      get_or_create_travel_preparation&.save if get_or_create_travel_preparation.changed?
    end
  end
end
