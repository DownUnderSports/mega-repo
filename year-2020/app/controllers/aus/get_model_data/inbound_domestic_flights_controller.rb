# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class InboundDomesticFlightsController < ::Aus::GetModelData::BaseCoachController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          airports = Flight::Airport.where(code: %w[ LAX YYZ YVR ])

          Enumerator.new do |y|
            airports.each do |airport|
              values = {}

              Traveler.active.where(departing_from: airport.code)

              airport.
                arriving_legs.
                group(:flight_number, :departing_at, :arriving_at, :arriving_airport_id, :departing_airport_id).
                select(:flight_number, :departing_at, :arriving_at, :arriving_airport_id, :departing_airport_id).
                order(:arriving_at, :departing_at, :flight_number).
                each do |leg|
                  legs = airport.
                    arriving_legs.
                    summary.
                    where(
                      flight_number:        leg.flight_number,
                      departing_at:         leg.departing_at,
                      arriving_at:          leg.arriving_at,
                      arriving_airport_id:  leg.arriving_airport_id,
                      departing_airport_id: leg.departing_airport_id,
                    )
                  coaches = []
                  inbound = []
                  legs.each do |l|
                    inbound << l.schedule.legs.
                      where("departing_at BETwEEN ? AND ?", l.departing_at - 24.hours, l.departing_at - 1.minute).
                      pluck(:id)

                    l.travelers.active.each {|t| coaches << "#{t.user.basic_name} (phone: #{t.user.ambassador_phone})" if t.user.is_coach? || (t.user.is_staff? && t.user.phone.present?) }
                  end

                  total = legs.sum('total_inbound')

                  date = leg.local_arriving_at.to_date.to_s

                  unless values[date]
                    own_d = Traveler.
                      active.
                      joins(:team).
                      where(departing_from: airport.code).
                      where("(COALESCE(travelers.departing_date, teams.departing_date) = ?)", Date.parse(date)).
                      where_not_exists(
                        :flight_legs,
                        "(arriving_airport_id IN (?)) AND (departing_at BETWEEN ? and ?)",
                        airports.select(:id),
                        Time.zone.parse(date).midnight.utc,
                        Time.zone.parse(date).end_of_day.utc
                      )
                    values[date] = [
                      {
                        flightNumber:   'Own Domestic',
                        departingAt:    'N/A',
                        departingFrom:  'N/A',
                        arrivingAt:     'N/A',
                        total:          own_d.size,
                        coaches:        [],
                        inbound:        own_d.map do |t|
                                          {
                                            flightNumber:  "#{t.user.dus_id}",
                                            departingAt:   t.user.category_title,
                                            departingFrom: t.user.basic_name,
                                            arrivingAt:    '',
                                            arrivingTo:    t.team.name,
                                            total:         '',
                                          }
                                        end,
                      }
                    ]
                  end

                  values[date] << {
                    flightNumber:  leg.flight_number,
                    departingAt:   leg.local_departing_at,
                    departingFrom: leg.departing_airport.code,
                    arrivingAt:    leg.local_arriving_at,
                    total:         total.to_i,
                    coaches:       coaches,
                    inbound:       (
                      Flight::Leg.where(id: inbound.flatten).
                        group(:flight_number, :departing_at, :arriving_at, :arriving_airport_id, :departing_airport_id).
                        select(:flight_number, :departing_at, :arriving_at, :arriving_airport_id, :departing_airport_id).
                        order(:departing_at, :arriving_at, :flight_number).
                        map do |l|
                          summary = l.arriving_airport.
                            arriving_legs.
                            summary.
                            where(
                              flight_number:        l.flight_number,
                              departing_at:         l.departing_at,
                              arriving_at:          l.arriving_at,
                              arriving_airport_id:  l.arriving_airport_id,
                              departing_airport_id: l.departing_airport_id,
                            )

                          {
                            flightNumber:  l.flight_number,
                            departingAt:   l.local_departing_at.strftime('%l:%M %p'),
                            departingFrom: l.departing_airport.code,
                            arrivingAt:    l.local_arriving_at.strftime('%l:%M %p'),
                            arrivingTo:    l.arriving_airport.code,
                            total:         summary.sum('total_inbound').to_i,
                          }
                        end
                    )
                  } if total.to_i > 0
                end

              values.each do |date, flights|
                y << {
                  date: date,
                  code: airport.code,
                  airport: airport,
                  flights: flights
                }
              end
            end
          end
        end

        def get_deleted_records
          []
        end
    end
  end
end
