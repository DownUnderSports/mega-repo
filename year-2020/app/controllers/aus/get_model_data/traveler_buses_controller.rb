# encoding: utf-8
# frozen_string_literal: true

module Aus
  module GetModelData
    class TravelerBusesController < ::Aus::GetModelData::BaseCoachController

      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================
      private
        def get_records
          buses = Traveler::Bus.all.joins(:sport).order("sports.abbr", "sports.abbr_gender", :name, :color, :id)

          if records_last_updated_at.present?
            buses = buses.
              where(
                'updated_at > ?',
                records_last_updated_at
              )
          end


          Enumerator.new(buses.size) do |y|
            buses.each do |bus|
              y << bus.as_json.merge(
                as_string: bus.to_str,
                sport_abbr: bus.sport.abbr_gender,
                sport_full: bus.sport.full_gender
              )
            end
          end
        end

        def get_deleted_records
          Traveler::Bus::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end
    end
  end
end
