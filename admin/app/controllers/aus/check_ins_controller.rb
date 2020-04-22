# encoding: utf-8
# frozen_string_literal: true

module Aus
  class CheckInsController < ::Aus::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      run_an_api_action do
        user = User[params[:dus_id]]

        raise 'User Not Found' unless user

        raise 'Birth Date Does Not Match' unless user.birth_date == Date.parse(params[:birth_date])

        arriving, departing = user.traveler.international_flights

        raise 'No International Flights' unless arriving.present? || departing.present?

        leg = (
            arriving \
              && (arriving.departing_at.to_i - Time.current.to_i).abs < 24.hours \
              && arriving
          ) \
          || (
            departing \
              && (departing.departing_at.to_i - Time.current.to_i).abs < 24.hours \
              && departing
          )

        raise 'No Flights Today' unless leg

        tickets = user.tickets.where(schedule_id: arriving.schedule_id)
        tickets.each do |ticket|
          ticket.update!(is_checked_in: true)

          puts ticket.as_json

          ActionCable.server.broadcast(
            'check_in',
            {
              action: 'checked-in',
              flight: ticket.as_json.merge({
                "category"             => ticket.user.category_title,
                "full_name"            => ticket.user.full_name,
                "date"                 => leg.local_departing_at.to_date.to_s,
                "code"                 => leg.departing_airport_code,
                "airport_name"         => leg.departing_airport.name,
                "user_id"              => ticket.user.id,
                "dus_id"               => ticket.user.dus_id,
                "local_departing_time" => leg.local_departing_at.strftime('%I:%M %p'),
                "wristband"            => ticket.user.bus&.color,
              })
            }
          )
        end
      end
    end

    # == Cleanup ============================================================
  end
end
