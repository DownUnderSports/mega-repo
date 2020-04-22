# encoding: utf-8
# frozen_string_literal: true

module Flight
  class Leg < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.flight_legs"

    attribute :arriving_airport_code, :text
    attribute :departing_airport_code, :text
    attribute :local_arriving_at, :datetime
    attribute :local_departing_at, :datetime

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :schedule,          class_name: 'Flight::Schedule'
    belongs_to :departing_airport, class_name: 'Flight::Airport', inverse_of: :departing_legs
    belongs_to :arriving_airport,  class_name: 'Flight::Airport', inverse_of: :arriving_legs

    has_many :tickets,
      through: :schedule,
      source: :tickets,
      inverse_of: :flight_legs

    has_many :travelers,
      through: :schedule,
      source: :travelers,
      inverse_of: :flight_legs


    # == Validations ==========================================================
    validate :valid_airport_codes
    validates_presence_of :arriving_at, :departing_at

    # == Scopes ===============================================================
    default_scope { default_order(:departing_at) }

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def initialize(*args)
      super(*args)

      begin
        attrs = args.first.to_h.deep_symbolize_keys
        %i[
          arriving_airport_code
          departing_airport_code
          local_arriving_at
          local_departing_at
        ].each do |k|
          self.__send__ "#{k}=", attrs[k] if attrs.key? k
        end
      rescue
        puts $!.message
      end

      self
    end

    def arriving_airport_code
      self.arriving_airport&.code
    rescue
      nil
    end

    def arriving_airport_code=(code)
      self[:arriving_airport_code] = code.to_s.strip.upcase.presence
      self.arriving_airport = get_airport_from_code(self[:arriving_airport_code])

      arriving_airport_code
    rescue
      errors.add(:arriving_airport_code, $!.message)
    end

    def departing_airport_code
      self.departing_airport&.code
    rescue
      nil
    end

    def departing_airport_code=(code)
      self[:departing_airport_code] = code.to_s.strip.upcase.presence
      self.departing_airport = get_airport_from_code(self[:departing_airport_code])

      departing_airport_code
    rescue
      errors.add(:departing_airport_code, $!.message)
    end

    def local_departing_at
      departing_airport.time_in_zone departing_at
    rescue
      nil
    end

    def local_departing_at=(datetime)
      self.departing_at = departing_airport.get_time_zone.local_to_utc(datetime)
    rescue
      nil
    end

    def local_arriving_at
      arriving_airport.time_in_zone arriving_at
    rescue
      nil
    end

    def local_arriving_at=(datetime)
      self.arriving_at = arriving_airport.get_time_zone.local_to_utc(datetime)
    rescue
      nil
    end

    def to_string
      "#{schedule.operator}: #{departing_airport_code}-#{arriving_airport_code} (#{flight_number})"
    end

    private
      def get_airport_from_code(code)
        code = code.to_s.strip.upcase

        unless airport = Flight::Airport.find_by(code: code)
          raise "\"#{code}\" Not Found"
        end

        airport
      end

      def valid_airport_codes
        [
          :arriving_airport_code,
          :departing_airport_code
        ].each do |m|
          get_airport_from_code(self[m]) if self[m].present?
        rescue
          errors.add(m, $!.message)
        end
      end

    set_audit_methods!
  end
end
