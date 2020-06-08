# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class FlightSchedulesController < ::Aus::GetModelData::BaseController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          Flight::Schedule.
            all.
            where(
              records_last_updated_at ? 'updated_at > ?' : '1=1',
              records_last_updated_at
            ).
            select(
              :id,
              :parent_schedule_id,
              :pnr,
              :carrier_pnr,
              :operator,
              :route_summary,
              :created_at,
              :updated_at
            )
        end

        def get_deleted_records
          Flight::Schedule::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end
    end
  end
end
