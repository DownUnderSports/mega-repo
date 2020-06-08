# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module Flights
      class TicketsController < ::Admin::ApplicationController
        # == Modules ============================================================

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.html do
              if Boolean.parse(params[:ground_only])
                @travelers =
                  Traveler.
                    active.
                    joins(:team, :user).
                    where(own_flights: true).
                    where('COALESCE(travelers.departing_date, teams.departing_date) = ?', params[:departing_date]).
                    where('COALESCE(travelers.returning_date, teams.returning_date) = ?', params[:returning_date])
              else
                @travelers =
                  Traveler.
                    active.
                    joins(:team, :user).
                    where(departing_from: params[:departing_from], returning_to: params[:returning_to]).
                    where('COALESCE(travelers.departing_date, teams.departing_date) = ?', params[:departing_date]).
                    where('COALESCE(travelers.returning_date, teams.returning_date) = ?', params[:returning_date])
              end

              if Boolean.parse(params[:with_balance])
                @travelers = @travelers.where(Traveler.arel_table[:balance].gt(0))
              end

              render :index, layout: false
            end
            format.json do
              return head 422 unless schedule = Flight::Schedule[params[:schedule_id]]
              return render json: {
                tickets: schedule.tickets.includes(:traveler).map do |ticket|
                  {
                    id:            ticket.id,
                    balance:       ticket.traveler.balance.to_s(true),
                    category:      ticket.user.category_title,
                    dus_id:        ticket.user.dus_id,
                    has_passport:  !!ticket.traveler.user.passport,
                    required:      ticket.required?,
                    status:        ticket.traveler.status,
                    team_name:     ticket.traveler.team.name,
                    ticket_number: ticket.ticket_number,
                    ticketed:      ticket.ticketed?,
                    total_paid:    ticket.traveler.total_payments.to_s(true),
                    traveler_id:   ticket.traveler_id,
                    ticket_count:  ticket.traveler.tickets.count,
                    given_names:   ticket.user.passport&.given_names \
                                   || ticket.user.first_names.upcase,
                    surname:       ticket.user.passport&.surname \
                                   || ticket.user.last_names.upcase,
                  }
                end
              }
            end
          end
        end

        def create
          run_an_api_action do
            traveler = User.get(params[:dus_id])&.traveler

            raise "Already Ticketed" if Flight::Ticket.find_by(traveler: traveler, schedule_id: params[:schedule_id])

            @ticket = Flight::Ticket.create(traveler: traveler, schedule_id: params[:schedule_id])

            unless @ticket.persisted?
              raise @ticket.errors.full_messages.join("\n")
            end

            @ticket
          end
        end

        def update
          run_an_api_action do
            raise "Ticket Not Found" unless @ticket = Flight::Ticket.find_by(id: params[:id])

            unless @ticket.update(required_or_ticketed_params)
              raise @ticket.errors.full_messages.join("\n")
            end

            @ticket
          end
        end

        def destroy
          run_an_api_action do
            raise "Ticket Not Found" unless @ticket = Flight::Ticket.find_by(id: params[:id])

            unless @ticket.destroy
              raise @ticket.errors.full_messages.join("\n")
            end

            nil
          end
        end

        # == Cleanup ============================================================

        # == Utilities ==========================================================
        private
          def whitelisted_flight_ticket_params
            params.
              require(:flight_ticket).
              permit(
                :id,
                :traveler_id,
                :schedule_id,
                :ticketed,
                :required,
                :ticket_number
              )
          end

          def required_or_ticketed_params
            params[:required].blank? && (false != params[:required]) \
              ? {
                  ticketed: Boolean.strict_parse(params[:ticketed]),
                  ticket_number: "#{params[:ticket_number]}".strip.presence
                } \
              : {
                  required: Boolean.strict_parse(params[:required])
                }
          end
      end
    end
  end
end
