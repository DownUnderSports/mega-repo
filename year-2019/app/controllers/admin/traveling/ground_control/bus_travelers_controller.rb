# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module GroundControl
      class BusTravelersController < ApplicationController
        # == Modules ============================================================

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.any do
              return head 422 unless bus = Traveler::Bus.find_by(id: params[:bus_id])
              return render json: {
                travelers: bus.travelers.includes(:rooms, :team, user: :passport).map do |traveler|
                  arriving, departing = traveler.international_flights

                  {
                    id:           traveler.id,
                    arriving:     arriving&.to_string,
                    balance:      traveler.balance.to_s(true),
                    category:     traveler.user.category_title,
                    departing:    departing&.to_string,
                    dus_id:       traveler.user.dus_id,
                    has_passport: !!traveler.user.passport,
                    rooms:        traveler.rooms.count,
                    status:       traveler.status,
                    team_name:    traveler.team.name,
                    total_paid:   traveler.total_payments.to_s(true),
                    given_names:  traveler.user.passport&.given_names \
                                  || traveler.user.first_names.upcase,
                    surname:      traveler.user.passport&.surname \
                                  || traveler.user.last_names.upcase,
                  }
                end
              }
            end
          end
        end

        def create
          run_an_api_action do
            raise "Traveler Not Found" unless traveler = User[params[:dus_id]]&.traveler

            raise "Bus Not Found" unless bus = Traveler::Bus.find(params[:bus_id])

            raise "Already Assigned" if traveler.buses.find(bus.id)

            sport_bus = traveler.buses.find_by(sport_id: bus.sport_id)

            raise "Duplicate Bus for Sport (#{sport_bus.to_str})" if sport_bus

            bus.travelers << traveler

            traveler.touch
            traveler.user.touch

            nil
          end
        end

        def destroy
          run_an_api_action do
            raise "Traveler Not Found" unless traveler = Traveler.find(params[:id])

            raise "Bus Not Found" unless bus = Traveler::Bus.find(params[:bus_id])

            bus.travelers.delete(traveler)

            nil
          end
        end

        # == Cleanup ============================================================

        # == Utilities ==========================================================

      end
    end
  end
end
