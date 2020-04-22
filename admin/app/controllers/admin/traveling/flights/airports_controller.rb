# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module Flights
      class AirportsController < ::Admin::ApplicationController
        # == Modules ============================================================
        include Filterable

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              base_airports = airports_list

              filter, options = filter_records(boolean_regex: /preferred|selected/)

              base_airports =
                filter ?
                  base_airports.where(filter, options.deep_symbolize_keys) :
                  base_airports

              airports = base_airports.
                order(*get_sort_params, :code, :country).
                offset((params[:page] || 0).to_i * 100).limit(100)

              headers["X-Accel-Buffering"] = 'no'

              expires_now
              headers["Content-Type"] = "application/json; charset=utf-8"
              headers["Content-Disposition"] = 'inline'
              headers["Content-Encoding"] = 'deflate'
              headers["Last-Modified"] = Time.zone.now.ctime.to_s

              self.response_body = Enumerator.new do |y|
                deflator = StreamJSONDeflator.new(y)

                deflator.stream false, :total, base_airports.count('1')
                deflator.stream true, :airports, '['

                i = 0
                airports.each do |airport|
                  deflator.stream (i += 1) > 1, nil, {
                    area: airport.area,
                    city: airport.city,
                    code: airport.code,
                    country: airport.country,
                    name: airport.name,
                    # track_departing_date: airport.track_departing_date&.to_s,
                    # track_returning_date: airport.track_returning_date&.to_s,
                    preferred: airport.preferred,
                    selectable: airport.selectable,
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
              @airport ||= Flight::Airport[params[:id]]

              render json: {
                id: @airport.id,
                code: @airport.code,
                name: @airport.name,
                carrier: @airport.carrier,
                cost: @airport.cost,
                tz_offset: @airport.tz_offset,
                dst: @airport.dst,
                location_override: @airport.location_override,
                track_departing_date: @airport.track_departing_date,
                track_returning_date: @airport.track_returning_date,
                preferred: @airport.preferred,
                selectable: @airport.selectable,
                created_at: @airport.created_at,
                updated_at: @airport.updated_at,
                address_attributes: {
                  id: @airport.address&.id,
                  is_foreign: @airport.address&.is_foreign,
                  street: @airport.address&.street,
                  street_2: @airport.address&.street_2,
                  street_3: @airport.address&.street_3,
                  city: @airport.address&.city,
                  state_id: @airport.address&.state_id,
                  province: @airport.address&.province,
                  zip: @airport.address&.zip,
                  country: @airport.address&.country,
                  tz_offset: @airport.address&.tz_offset,
                  dst: @airport.address&.dst,
                  rejected: @airport.address&.rejected,
                  verified: @airport.address&.verified,
                  created_at: @airport.address&.created_at,
                  updated_at: @airport.address&.updated_at
                }
              }.null_to_str
            end
          end
        rescue NoMethodError
          return not_authorized([
            'Airport not found',
            $!.message
          ], 422)
        end

        def new
          @airport = Flight::Airport.new carrier: 'qantas'
          return show
        end

        def create
          run_an_api_action do
            Flight::Airport.create!(whitelisted_airport_params)
          end
        end

        def update
          run_an_api_action do
            airport = Flight::Airport[params[:id]]

            airport.update!(whitelisted_airport_params)

            airport
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
              :area,
              :city,
              :code,
              :country,
              :name,
              :preferred,
              :selectable,
            ].freeze
          end

          def default_sort_order
            []
          end

          def airports_list
            Flight::Airport.joins(
              <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                INNER JOIN (
                  SELECT
                    flight_airports.id AS inner_airport_id,
                    addresses.city AS city,
                    COALESCE(states.abbr, addresses.province) AS area,
                    COALESCE(addresses.country, 'USA') AS country
                  FROM
                    flight_airports
                  LEFT JOIN
                    addresses ON addresses.id = flight_airports.address_id
                  LEFT JOIN
                    states ON states.id = addresses.state_id
                ) flight_addresses ON flight_addresses.inner_airport_id = flight_airports.id
              SQL
            ).
            select(
              "flight_airports.*",
              "flight_addresses.area",
              "flight_addresses.city",
              "flight_addresses.country"
            )
          end

          def whitelisted_airport_params
            params.require(:airport).
              permit(
                :id,
                :code,
                :name,
                :carrier,
                :cost,
                :preferred,
                :dst,
                :tz_offset,
                :location_override,
                :track_departing_date,
                :track_returning_date,
                address_attributes: [
                  :id,
                  :is_foreign,
                  :street,
                  :street_2,
                  :street_3,
                  :city,
                  :state_id,
                  :province,
                  :zip,
                  :country,
                  :tz_offset,
                  :dst,
                ],
              )
          end
      end
    end
  end
end
