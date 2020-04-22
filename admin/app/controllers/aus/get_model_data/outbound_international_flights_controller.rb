# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class OutboundInternationalFlightsController < ::Aus::GetModelData::BaseCoachController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          legs = get_legs
          tickets = get_tickets legs

          Enumerator.new(tickets.size) do |y|
            legs.each do |leg|
              tickets.
                where(schedule_id: leg.schedule_id).each do |ticket|
                  next unless ticket.traveler.active?

                  y << ticket.as_json.merge({
                    "category"             => ticket.user.category_title,
                    "full_name"            => ticket.user.full_name,
                    "date"                 => leg.local_departing_at.to_date.to_s,
                    "code"                 => leg.departing_airport_code,
                    "airport_name"         => leg.departing_airport.name,
                    "user_id"              => ticket.user.id,
                    "dus_id"               => ticket.user.dus_id,
                    "local_departing_time" => leg.local_departing_at.strftime('%I:%M %p'),
                    "wristband"            => ticket.user.bus&.color,
                    "updated_at"           => [ ticket.updated_at, ticket.traveler.updated_at ].max
                  })
                end
            end
          end
        end

        def get_airports
          Flight::Airport.
            joins(:address).
            where(addresses: { is_foreign: true }).
            where.not(addresses: { country: 'CAN' })
        end

        def get_legs
          airports = get_airports
          Flight::Leg.
            where(arriving_airport: airports).
            where.not(departing_airport: airports).
            order(:departing_at, :arriving_at, :flight_number)
        end

        def get_tickets(legs)
          Flight::Ticket.
            includes(:traveler).
            joins(:traveler).
            where(travelers: { cancel_date: nil }).
            where_exists(:schedule, id: legs.select(:schedule_id)).
            where(
              records_last_updated_at ? '(flight_tickets.updated_at > ?) OR (travelers.updated_at > ?)' : '1=1',
              records_last_updated_at,
              records_last_updated_at
            )
        end



        def get_deleted_records
          tickets = Flight::Ticket::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at)

          travelers = Traveler.
            where.not(cancel_date: nil).
            where(
              'updated_at > ?',
              records_last_updated_at
            )
          Enumerator.new(tickets.size + travelers.size) do |y|
            tickets.split_batches_values do |deleted|
              y << deleted.row_data
            end

            travelers.split_batches_values do |t|
              t.tickets.each do |ticket|
                y << ticket
              end
            end
          end
        end
    end
  end
end
