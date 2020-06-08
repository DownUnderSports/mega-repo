# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module GroundControl
      class RoomsController < ::Admin::ApplicationController
        # == Modules ============================================================

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.any do
              return head 422 unless hotel = Traveler::Hotel.find_by(id: params[:hotel_id])
              return render json: {
                rooms: hotel.rooms.includes(traveler: [:rooms, :team, user: :passport]).map do |room|
                  traveler = room.traveler
                  arriving, departing = traveler.international_flights

                  {
                    id:             room.id,
                    arriving:       arriving&.to_string,
                    category:       traveler.user.category_title,
                    check_in_date:  room.check_in_date.to_s,
                    check_out_date: room.check_out_date.to_s,
                    departing:      departing&.to_string,
                    dus_id:         traveler.user.dus_id,
                    number:         room.number.to_s,
                    total_rooms:    traveler.rooms.count,
                    status:         traveler.status,
                    team_name:      traveler.team.name,
                    given_names:    traveler.user.passport&.given_names \
                                    || traveler.user.first_names.upcase,
                    surname:        traveler.user.passport&.surname \
                                    || traveler.user.last_names.upcase,
                  }.null_to_str
                end
              }, status: 200
            end
          end
        end

        def create
          run_an_api_action do
            raise "Traveler Not Found" unless traveler = User[params[:dus_id]]&.traveler

            raise "Hotel Not Found" unless hotel = Traveler::Hotel.find(params[:hotel_id])

            traveler.rooms.create!(
              hotel: hotel,
              check_in_date: params[:check_in_date].presence || traveler.arriving_flight&.local_arriving_at&.to_date,
              check_out_date: params[:check_out_date].presence || traveler.departing_flight&.local_arriving_at&.to_date
            )

            nil
          end
        end

        def update
          run_an_api_action do
            raise "Room Not Found" unless room = Traveler::Room.find(params[:id])

            unless room.update(whitelisted_room_params)
              raise room.errors.full_messages.join("\n")
            end

            room
          end
        end

        def destroy
          run_an_api_action do
            raise "Room Not Found" unless room = Traveler::Room.find(params[:id])

            room.destroy!

            nil
          end
        end

        # == Cleanup ============================================================

        # == Utilities ==========================================================
        private
          def whitelisted_room_params
            params.require(:room).permit(
              :check_in_date,
              :check_out_date,
              :number
            )
          end

      end
    end
  end
end
