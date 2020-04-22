# encoding: utf-8
# frozen_string_literal: true

module Travel
  module GetModelData
    class UsersController < ::Travel::GetModelData::BaseController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================

      # == Cleanup ============================================================

      private
        def get_records
          [
            current_user
          ]
        end

        def get_deleted_records
          User::LoggedAction.
            where(action: 'D').
            where("action_tstamp_stm > ?", records_last_updated_at).
            pluck(:row_data)
        end

        def json_args
          [
            {
              include: [
                traveler: {
                  include: [
                    {
                      tickets: {
                        include: [
                          :schedule,
                          {
                            flight_legs: {
                              include: {
                                arriving_airport: { include: :address },
                                departing_airport: { include: :address }
                              }
                            },
                          }
                        ]
                      },
                      flight_legs: {
                        include: [
                          arriving_airport: { include: :address },
                          departing_airport: { include: :address },
                        ]
                      },
                    },
                    :team,
                    {
                      competing_teams: {
                        include: [
                          :sport,
                          :coach_users
                        ]
                      }
                    }
                  ]
                }
              ]
            }
          ]
        end
    end
  end
end
