# encoding: utf-8
# frozen_string_literal: true

module Travel
  module GetModelData
    class FlightAirportsController < ::Travel::GetModelData::BaseController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          Flight::Airport.
            includes(:address)
            where(
              "((id IN (?)) OR (id IN (?)))",
              current_user.traveler.arriving_airports.select(:id),
              current_user.traveler.departing_airports.select(:id)
            ).
            where(
              records_last_updated_at ? 'updated_at > ?' : '1=1',
              records_last_updated_at
            )
        rescue
          []
        end

        def get_deleted_records
          Flight::Airport::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end

        def json_args
          [ { include: :address } ]
        end
    end
  end
end
