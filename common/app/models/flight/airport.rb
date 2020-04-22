# encoding: utf-8
# frozen_string_literal: true

module Flight
  class Airport < ApplicationRecord
    # == Constants ============================================================

    # DST_TZINFO

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================

    has_many :arriving_legs,
      class_name: 'Flight::Leg',
      foreign_key: :arriving_airport_id do
        def summary
          joins(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              INNER JOIN (
                SELECT
                  flight_tickets.schedule_id,
                  COUNT(flight_tickets.id) AS total_inbound,
                  MAX(flight_tickets.updated_at) AS tickets_updated_at
                FROM
                  flight_tickets
                INNER JOIN travelers
                  ON travelers.id = flight_tickets.traveler_id
                WHERE
                  (flight_tickets.ticketed = TRUE)
                  AND
                  (travelers.cancel_date IS NULL)
                GROUP BY
                  flight_tickets.schedule_id
              ) ticket_summary ON ticket_summary.schedule_id = flight_legs.schedule_id
            SQL
          ).
          select(
            'flight_legs.*',
            'ticket_summary.total_inbound',
            'ticket_summary.tickets_updated_at'
          )
        end
      end

    has_many :arriving_travelers,
      through: :arriving_legs,
      source: :travelers,
      inverse_of: :arriving_airports

    has_many :departing_legs,
      class_name: 'Flight::Leg',
      foreign_key: :departing_airport_id

    has_many :departing_travelers,
      through: :departing_legs,
      source: :travelers,
      inverse_of: :departing_airports

    has_many :departing_tickets,
      through: :departing_legs,
      source: :tickets

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :set_tz_offset
    after_touch :check_tz_offset

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.get_time_zone(offset, dst = false)
      DST_TZINFO["#{offset}#{dst ? 'Y' : 'N'}"]
    end

    def self.new(attrs = {})
      return super(attrs) if attrs.blank?
      attrs = attrs.attributes if attrs.is_a?(ActiveRecord::Base)
      super(attrs.to_h.with_indifferent_access.merge(normalize(attrs.to_h.with_indifferent_access)))
    end

    def self.normalize(airport)
      airport = airport.with_indifferent_access if airport.is_a?(Hash)

      {
        code: airport['code'].to_s.upcase.to_s[0..2].presence,
        name: airport['name'].to_s.titleize.presence,
        carrier: airport['carrier'].to_s.downcase.presence,
        tz_offset: normalize_tz_offset(airport['tz_offset']),
        dst: Boolean.strict_parse(airport['dst']),
        preferred: Boolean.strict_parse(airport['preferred']),
        selectable: Boolean.strict_parse(airport['selectable']),
      }
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def dst
      (!address&.is_foreign && address&.dst) || self[:dst]
    end

    def get_time_zone
      self.class.get_time_zone(tz_offset, dst)
    end

    def to_card_string
      %Q(
        #{
          location_override.presence \
          || "#{
                address.city.upcase
              }, #{
                ((state = address.province_or_state_abbr.upcase).size > 3) ? address.country : state
              }"
        } (#{code})
      )
    end

    def to_desc
      return nil unless address
      [
        "#{name}, #{address.province_or_state_abbr}",
        "#{address.city}, #{address.province_or_state_abbr}"
      ]
    end

    def time_in_zone(utc)
      z = get_time_zone
      raise "Time Zone Not Found" unless z
      utc.in_time_zone z
    rescue
      utc
    end

    def tz_offset
      return self[:tz_offset] if destroyed?
      self[:tz_offset] = normalize_tz_offset((!address&.is_foreign && address&.tz_offset) || self[:tz_offset])
    end

    private
      def check_tz_offset
        self.save if self[:tz_offset] != self.tz_offset

        true
      end

      def set_tz_offset
        self.tz_offset
        true
      end

    set_audit_methods!
  end
end

ValidatedAddresses
