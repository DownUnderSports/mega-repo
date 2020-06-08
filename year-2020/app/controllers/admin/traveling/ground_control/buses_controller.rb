# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module GroundControl
      class BusesController < ::Admin::ApplicationController
        # == Modules ============================================================
        include Filterable

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              base_buses = buses_list

              filter, options = filter_records

              base_buses =
                filter ?
                  base_buses.where(filter, options.deep_symbolize_keys) :
                  base_buses

              buses = base_buses.
                order(*get_sort_params, :sport_abbr, :color).
                offset((params[:page] || 0).to_i * 100).limit(100)

              headers["X-Accel-Buffering"] = 'no'

              expires_now
              headers["Content-Type"]        = "application/json; charset=utf-8"
              headers["Content-Disposition"] = 'inline'
              headers["Content-Encoding"]    = 'deflate'
              headers["Last-Modified"]       = Time.zone.now.ctime.to_s

              self.response_body = Enumerator.new do |y|
                deflator = StreamJSONDeflator.new(y)

                deflator.stream false, :total, base_buses.count('1')
                deflator.stream true, :buses, '['

                i = 0
                buses.each do |bus|
                  deflator.stream (i += 1) > 1, nil, {
                    id:         bus.id,
                    assigned:   bus.assigned,
                    color:      bus.color,
                    hotel_name: bus.hotel_name,
                    name:       bus.name,
                    sport_abbr: bus.sport_abbr,
                  }
                end

                deflator.stream false, nil, ']'

                deflator.close
              end
            end
          end
        end

        def show
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              @bus ||= Traveler::Bus.find(params[:id])

              render json: {
                id:         @bus.id,
                combo:      @bus.name,
                color:      @bus.color,
                details:    @bus.details,
                name:       @bus.name,
                hotel_id:   @bus.hotel_id,
                sport_abbr: @bus.sport_abbr,
                sport_id:   @bus.sport_id,
                link:       @bus.persisted? ? url_with_auth(admin_traveling_ground_control_bus_path(@bus, format: :pdf)) : '',
                colors:     Traveler::Bus.combos.map do |(name, color)|
                              {
                                color: color,
                                label: "#{name} - #{color}",
                                name: name,
                                value: name,
                              }
                            end
              }.null_to_str
            end
            format.pdf do
              @competing_team ||= Traveler::Bus.find(params[:id])

              render pdf: "#{@competing_team.sport.full_gender} Roster - #{@competing_team.name} - #{Time.now.to_s(:db).gsub(/\s/, '_')}",
                     template: 'admin/traveling/ground_control/competing_teams/show',
                     show_as_html: true
            end
            format.csv do
              @competing_team ||= Traveler::Bus.find(params[:id])
              return render csv: "competing_team",
                     template: 'admin/traveling/ground_control/competing_teams/show',
                     filename: "#{@competing_team.to_str} Roster",
                     with_time: true
            end
          end
        rescue NoMethodError
          return not_authorized([
            'Bus not found',
            $!.message
          ], 422)
        end

        def teammates
          @competing_team ||= Traveler::Bus.find(params[:id])

          render pdf: "#{@competing_team.sport.full_gender} Roster - #{@competing_team.name} - #{Time.now.to_s(:db).gsub(/\s/, '_')}",
                 template: 'admin/traveling/ground_control/competing_teams/teammates',
                 show_as_html: true
        rescue NoMethodError
          return not_authorized([
            'Competing Team not found',
            $!.message
          ], 422)
        end

        def new
          @bus = Traveler::Bus.new
          return show
        end

        def create
          run_an_api_action do
            Traveler::Bus.create!(whitelisted_bus_params)
          end
        end

        def update
          run_an_api_action do
            (bus = Traveler::Bus.find(params[:id])).update!(whitelisted_bus_params)

            bus
          end
        end

        # == Cleanup ============================================================

        # == Utilities ==========================================================

        private
          def whitelisted_filter_params
            params.permit(allowed_keys)
          end

          def allowed_keys
            @allowed_keys ||= [
              :assigned,
              :color,
              :hotel_name,
              :name,
              :sport_abbr,
            ].freeze
          end

          def default_sort_order
            []
          end

          def buses_list
            Traveler::Bus.
              joins(
                <<-SQL.gsub(/\s*(\n\s*|\s+)/m, ' ')
                  INNER JOIN (
                    SELECT
                      traveler_buses.id AS bus_id,
                      sports.abbr_gender AS sport_abbr,
                      traveler_hotels.name AS hotel_name,
                      COALESCE(traveler_counts.assigned, 0) AS assigned
                    FROM
                      traveler_buses
                    INNER JOIN sports
                      ON sports.id = traveler_buses.sport_id
                    LEFT JOIN traveler_hotels
                      ON traveler_hotels.id = traveler_buses.hotel_id
                    LEFT JOIN (
                      SELECT
                        bus_id,
                        COUNT(traveler_id) AS assigned
                      FROM
                        traveler_buses_travelers
                      WHERE
                        traveler_id IN (#{Traveler.active.select(:id).to_sql})
                      GROUP BY
                        bus_id
                    ) traveler_counts
                      ON traveler_counts.bus_id = traveler_buses.id
                  ) bus_infos
                    ON bus_infos.bus_id = traveler_buses.id
                SQL
              ).
              select(
                "traveler_buses.*",
                "bus_infos.hotel_name",
                "bus_infos.sport_abbr",
                "bus_infos.assigned",
              )
          end

          def whitelisted_bus_params
            params.require(:bus).
              permit(
                :id,
                :sport_id,
                :hotel_id,
                :combo,
                :details,
              )
          end
      end
    end
  end
end
