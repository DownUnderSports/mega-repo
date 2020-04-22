# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module GroundControl
      class HotelsController < ::Admin::ApplicationController
        # == Modules ============================================================
        include Filterable

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              base_hotels = hotels_list

              filter, options = filter_records

              base_hotels =
                filter ?
                  base_hotels.where(filter, options.deep_symbolize_keys) :
                  base_hotels

              hotels = base_hotels.
                order(*get_sort_params, :name, :country).
                offset((params[:page] || 0).to_i * 100).limit(100)

              headers["X-Accel-Buffering"] = 'no'

              expires_now
              headers["Content-Type"] = "application/json; charset=utf-8"
              headers["Content-Disposition"] = 'inline'
              headers["Content-Encoding"] = 'deflate'
              headers["Last-Modified"] = Time.zone.now.ctime.to_s

              self.response_body = Enumerator.new do |y|
                deflator = StreamJSONDeflator.new(y)

                deflator.stream false, :total, base_hotels.count('1')
                deflator.stream true, :hotels, '['

                i = 0
                hotels.each do |hotel|
                  deflator.stream (i += 1) > 1, nil, {
                    id: hotel.id,
                    area: hotel.area,
                    city: hotel.city,
                    country: hotel.country,
                    name: hotel.name,
                    phone: hotel.phone,
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
              @hotel ||= Traveler::Hotel[params[:id]]

              render json: {
                id:         @hotel.id,
                name:       @hotel.name,
                phone:      @hotel.phone,
                contacts:   @hotel.contacts || [],
                created_at: @hotel.created_at,
                updated_at: @hotel.updated_at,
                address_attributes: {
                  id:         @hotel.address&.id,
                  is_foreign: @hotel.address&.is_foreign,
                  street:     @hotel.address&.street,
                  street_2:   @hotel.address&.street_2,
                  street_3:   @hotel.address&.street_3,
                  city:       @hotel.address&.city,
                  state_id:   @hotel.address&.state_id,
                  province:   @hotel.address&.province,
                  zip:        @hotel.address&.zip,
                  country:    @hotel.address&.country,
                  tz_offset:  @hotel.address&.tz_offset,
                  dst:        @hotel.address&.dst,
                  rejected:   @hotel.address&.rejected,
                  verified:   @hotel.address&.verified,
                  created_at: @hotel.address&.created_at,
                  updated_at: @hotel.address&.updated_at,
                }
              }.null_to_str
            end
          end
        rescue NoMethodError
          return not_authorized([
            'Hotel not found',
            $!.message
          ], 422)
        end

        def new
          @hotel = Traveler::Hotel.new
          return show
        end

        def create
          run_an_api_action do
            Traveler::Hotel.create!(whitelisted_hotel_params)
          end
        end

        def update
          run_an_api_action do
            hotel = Traveler::Hotel[params[:id]]
            hotel.update!(whitelisted_hotel_params)

            hotel
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
              :country,
              :name,
              :phone,
            ].freeze
          end

          def default_sort_order
            []
          end

          def hotels_list
            Traveler::Hotel.joins(
              <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                INNER JOIN (
                  SELECT
                    traveler_hotels.id AS inner_hotel_id,
                    addresses.city AS city,
                    COALESCE(states.abbr, addresses.province) AS area,
                    COALESCE(addresses.country, 'USA') AS country
                  FROM
                    traveler_hotels
                  LEFT JOIN
                    addresses ON addresses.id = traveler_hotels.address_id
                  LEFT JOIN
                    states ON states.id = addresses.state_id
                ) traveler_addresses ON traveler_addresses.inner_hotel_id = traveler_hotels.id
              SQL
            ).
            select(
              "traveler_hotels.*",
              "traveler_addresses.area",
              "traveler_addresses.city",
              "traveler_addresses.country"
            )
          end

          def whitelisted_hotel_params
            params.require(:hotel).
              permit(
                :id,
                :name,
                :phone,
                contacts: [],
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
