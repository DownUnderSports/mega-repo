# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class TravelerBusesTravelersController < ::Aus::GetModelData::BaseController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          Traveler::BusesTraveler.
            all.
            where(
              records_last_updated_at ? 'updated_at > ?' : '1=1',
              records_last_updated_at
            )
        end

        def get_deleted_records
          Traveler::BusesTraveler::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end
    end
  end
end
