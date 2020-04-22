# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module Flights
      class SchedulesController < Admin::ApplicationController
        # == Modules ============================================================
        include Filterable

        IDBuilder = Struct.new(:id)

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def air_canada
          respond_to do |format|
            format.xlsx do
              Traveler.set_balances

              value = IDBuilder.new(current_user&.email || 'it@downundersports.com')


              FileMailer.
                with(
                  email: value.id,
                  name: 'names_list_air_canada',
                  mime_type: 'xlsx',
                  handler: 'axlsx',
                  extension: 'xlsx',
                  template: 'admin/traveling/flights/schedules/air_canada',
                  message: 'Here is your Air Canada Worksheet',
                  subject: 'Air Canada Worksheet'
                ).
                send_file.
                deliver_later(queue: :staff_mailer)

              value
            end
          end
        end

        def srdocs
          run_an_api_action do
            value = IDBuilder.new(current_user&.email || 'it@downundersports.com')


            FileMailer.
              with(
                email: value.id,
                name: 'srdocs_by_carrier',
                mime_type: 'xlsx',
                handler: 'axlsx',
                extension: 'xlsx',
                template: 'admin/traveling/flights/schedules/srdocs',
                message: 'Here is your SRDoc File',
                subject: 'SR Docs Worksheet'
              ).
              send_file.
              deliver_later(queue: :staff_mailer)

            value
          end
        end

        def virgin_australia
          respond_to do |format|
            format.xlsx do
              Traveler.set_balances

              value = IDBuilder.new(current_user&.email || 'it@downundersports.com')


              FileMailer.
                with(
                  email: value.id,
                  name: 'names_list_virgin_australia',
                  mime_type: 'xlsx',
                  handler: 'axlsx',
                  extension: 'xlsx',
                  template: 'admin/traveling/flights/schedules/virgin_australia',
                  message: 'Here is your Virgin Australia Worksheet',
                  subject: 'Virgin Australia Worksheet'
                ).
                send_file.
                deliver_later(queue: :staff_mailer)

              value
            end
          end
        end

        def index
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              base_schedules = schedules_list

              filter, options = filter_records(utc_dates: true)

              base_schedules =
                filter ?
                  base_schedules.where(filter, options.deep_symbolize_keys) :
                  base_schedules

              schedules = base_schedules.
                order(*get_sort_params, :departing_at, :departing_from, :pnr, :carrier_pnr).
                offset((params[:page] || 0).to_i * 100).limit(100)

              headers["X-Accel-Buffering"] = 'no'

              expires_now
              headers["Content-Type"] = "application/json; charset=utf-8"
              headers["Content-Disposition"] = 'inline'
              headers["Content-Encoding"] = 'deflate'
              headers["Last-Modified"] = Time.zone.now.ctime.to_s

              self.response_body = Enumerator.new do |y|
                deflator = StreamJSONDeflator.new(y)

                deflator.stream false, :total, base_schedules.count('1')
                deflator.stream true, :schedules, '['

                i = 0
                schedules.each do |schedule|
                  deflator.stream (i += 1) > 1, nil, {
                    arriving_at:       schedule.arriving_at&.strftime('%Y-%m-%d'),
                    arriving_to:       schedule.arriving_to,
                    booking_reference: schedule.booking_reference,
                    cancels_count:     schedule.cancels_count,
                    carrier_pnr:       schedule.carrier_pnr,
                    departing_at:      schedule.departing_at&.strftime('%Y-%m-%d'),
                    departing_from:    schedule.departing_from,
                    names_assigned:    schedule.names_assigned,
                    operator:          schedule.operator,
                    pnr:               schedule.pnr,
                    route_summary:     schedule.route_summary,
                    seats_reserved:    schedule.seats_reserved,
                    totals_count:      schedule.totals_count,
                  }
                end

                deflator.stream false, nil, ']'

                deflator.close
              end
            end
            format.xlsx do
              run_an_api_action do
                value = IDBuilder.new(current_user&.email || 'it@downundersports.com')

                FileMailer.
                  with(
                    email: value.id,
                    name: 'flight_schedules',
                    mime_type: 'xlsx',
                    handler: 'axlsx',
                    extension: 'xlsx',
                    template: 'admin/traveling/flights/schedules/index',
                    message: 'Here is your Schedule Worksheet',
                    subject: 'Flight Schedule Worksheet'
                  ).
                  send_file.
                  deliver_later(queue: :staff_mailer)

                value
              end
            end
          end
        end

        def show
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              @schedule ||= Flight::Schedule[params[:id]]
              @schedule && (10 - @schedule.legs.size).times { @schedule.legs.build }

              render json: {
                id:                 @schedule.id,
                pnr:                @schedule.pnr,
                carrier_pnr:        @schedule.carrier_pnr,
                operator:           @schedule.operator,
                parent_schedule_id: @schedule.parent_schedule_id,
                amount:             @schedule.amount,
                seats_reserved:     @schedule.seats_reserved,
                names_assigned:     @schedule.names_assigned,
                booking_reference:  @schedule.booking_reference,
                rtaxr:              @schedule.rtaxr,
                legs_attributes:    @schedule.legs.map do |leg|
                  {
                    id:                     leg.id,
                    flight_number:          leg.flight_number,
                    departing_airport_code: leg.departing_airport_code,
                    local_departing_at:     leg.local_departing_at&.strftime('%Y-%m-%d %I:%M %p'),
                    arriving_airport_code:  leg.arriving_airport_code,
                    local_arriving_at:      leg.local_arriving_at&.strftime('%Y-%m-%d %I:%M %p'),
                    overnight:              leg.overnight,
                    is_subsidiary:          leg.is_subsidiary,
                  }.null_to_str
                end
              }.null_to_str
            end
            format.pdf do
              unless @schedule
                return redirect_to admin_traveling_flights_schedules_path(format: :html)
              end
              return render pdf: "schedule-#{@schedule.pnr}", template: 'shared/pdf/schedule', layout: 'layouts/multi.pdf.erb', locals: {schedule: @schedule}, show_as_html: true
            end
          end
        rescue NoMethodError
          return not_authorized([
            'Schedule not found',
            $!.message
          ], 422)
        end

        def new
          return not_authorized("CANNOT ADD/REMOVE/MODIFY FLIGHTS IN PREVIOUS YEARS", 422)
        end

        def create
          return new
        end

        def update
          return new
        end

        def trip_details_download
          send_file Rails.root.join('tmp', 'trip_details', 'trip_details.zip'), type: 'application/zip; charset=utf-8', disposition: "attachment; filename=\"trip_details_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.zip\""
        end

        def download
          p params
          f_name = "#{params[:verified].present? ? "#{params[:verified] == 'no' ? 'un' : ''}verified_" : ''}schedules"
          send_file Rails.root.join('tmp', f_name, "#{f_name}.zip"), type: 'application/zip; charset=utf-8', disposition: "attachment; filename=\"#{f_name}_#{Time.now.strftime('%Y-%m-%d_%H-%M-%S')}.zip\""
        end

        # == Cleanup ============================================================

        # == Utilities ==========================================================

        private
          def whitelisted_filter_params
            params.permit(allowed_keys)
          end

          def render_success(*args)
            render json: {
              id: @schedule&.pnr || args[0].presence,
              success: true
            }, status: 200
          end

          def run_a_schedule_action
            run_an_api_action do
              if whitelisted_flight_schedule_params[:original_value].present?
                @schedule =
                  Flight::Schedule.
                    parse!(whitelisted_flight_schedule_params[:original_value])
              else
                yield
              end
            end
          end

          def allowed_keys
            @allowed_keys ||= [
              :arriving_at,
              :arriving_offset,
              :arriving_to,
              :booking_reference,
              :cancels_count,
              :carrier_pnr,
              :departing_at,
              :departing_from,
              :departing_offset,
              :names_assigned,
              :operator,
              :pnr,
              :route_summary,
              :seats_reserved,
            ].freeze
          end

          def default_sort_order
            []
          end

          def schedules_list
            Flight::Schedule.
              joins(
                <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                  INNER JOIN (
                    SELECT
                      flight_schedules.id AS inner_schedule_id,
                      (
                        CASE
                        WHEN
                          ( first_legs.departing_at IS NULL )
                        THEN NULL
                        ELSE (
                          first_legs.departing_at + (
                            (
                              COALESCE(departing_airports.tz_offset, 0) + (
                                CASE
                                WHEN
                                  ( departing_airports.dst )
                                THEN ( 60 * 60 )
                                ELSE 0
                                END
                              )
                            ) * interval '1 second'
                          )
                        )
                        END
                      ) AS departing_at,
                      (
                        CASE
                        WHEN
                          ( last_legs.arriving_at IS NULL )
                        THEN NULL
                        ELSE (
                          last_legs.arriving_at + (
                            (
                              COALESCE(arriving_airports.tz_offset, 0) + (
                                CASE
                                WHEN
                                  ( arriving_airports.dst )
                                THEN ( 60 * 60 )
                                ELSE 0
                                END
                              )
                            ) * interval '1 second'
                          )
                        )
                        END
                      ) AS arriving_at,
                      arriving_airports.code AS arriving_to,
                      departing_airports.code AS departing_from
                    FROM
                      flight_schedules
                    LEFT JOIN flight_legs first_legs
                      ON (
                        first_legs.id = (
                          SELECT
                            flight_legs.id
                          FROM
                            flight_legs
                          WHERE
                            schedule_id = flight_schedules.id
                          ORDER BY
                            flight_legs.departing_at ASC
                          LIMIT 1
                        )
                      )
                    LEFT JOIN flight_legs last_legs
                      ON (
                        last_legs.id = (
                          SELECT
                            flight_legs.id
                          FROM
                            flight_legs
                          WHERE
                            schedule_id = flight_schedules.id
                          ORDER BY
                            flight_legs.arriving_at DESC
                          LIMIT 1
                        )
                      )
                    LEFT JOIN flight_airports departing_airports
                      ON departing_airports.id = first_legs.departing_airport_id
                    LEFT JOIN flight_airports arriving_airports
                      ON arriving_airports.id = last_legs.arriving_airport_id
                  ) flight_infos ON flight_infos.inner_schedule_id = flight_schedules.id
                SQL
              ).
              joins(
                <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                  INNER JOIN (
                    SELECT
                      flight_schedules.id AS schedule_id,
                      COALESCE(cancel_counts.cancels_count, 0) AS cancels_count,
                      COALESCE(total_counts.totals_count, 0) AS totals_count
                    FROM
                      flight_schedules
                    LEFT JOIN (
                      SELECT
                        flight_tickets.schedule_id,
                        COUNT(flight_tickets.id) cancels_count
                      FROM
                        flight_tickets
                      INNER JOIN travelers
                        ON travelers.id = flight_tickets.traveler_id
                      WHERE
                        travelers.cancel_date IS NOT NULL
                      GROUP BY
                        flight_tickets.schedule_id
                    ) cancel_counts ON cancel_counts.schedule_id = flight_schedules.id
                    LEFT JOIN (
                      SELECT
                        flight_tickets.schedule_id,
                        COUNT(flight_tickets.id) totals_count
                      FROM
                        flight_tickets
                      INNER JOIN travelers
                        ON travelers.id = flight_tickets.traveler_id
                      GROUP BY
                        flight_tickets.schedule_id
                    ) total_counts ON total_counts.schedule_id = flight_schedules.id
                  ) traveler_counts ON traveler_counts.schedule_id = flight_schedules.id
                SQL
              ).
              select(
                :booking_reference,
                :carrier_pnr,
                :names_assigned,
                :operator,
                :pnr,
                :route_summary,
                :seats_reserved,
                "flight_infos.arriving_at",
                "flight_infos.arriving_to",
                "traveler_counts.cancels_count",
                "traveler_counts.totals_count",
                "flight_infos.departing_at",
                "flight_infos.departing_from",
              )
          end

          def parse_html_params
            errors = []
            whitelisted = whitelisted_flight_schedule_params.to_h.deep_symbolize_keys
            if whitelisted[:legs_attributes].present?
              time_reg = /20(19|2[1-9])-(?:0[1-9]|1[0-2])-(?:(?:0[1-9]|1[0-9]|2[0-9])|3(?:0|1))\s(?:0[1-9]|1[0-2]):[0-5][0-9]\s(?:A|P)M/
              valid_time = ->(time) { time.present? && (time =~ time_reg) }

              whitelisted[:legs_attributes].each do |leg_h|
                if leg_h.except(:is_subsidiary).values.all? &:blank?
                  next
                else
                  @is_deleting ||= Boolean.parse(leg_h[:_destroy])
                  [
                    :local_departing_at,
                    :local_arriving_at
                  ].each do |time_key|
                    if valid_time.call(leg_h[time_key]) &&
                      (
                        (
                          t_matches = leg_h[time_key].upcase.match(/([0-9]+)-([0-9]+)-([0-9]+)\s+([0-9]+):([0-9]+)\s([AP]M)/).to_a[1..-1]
                        ).size == 6
                      )

                      am_pm = t_matches.pop
                      t_matches.map! &:to_i
                      t_matches[-2] = ((t_matches[-2] == 12) ? 0 : t_matches[-2]) + (am_pm == 'PM' ? 12 : 0)
                      leg_h[time_key] = DateTime.new(*t_matches, 0)
                    else
                      errors << "#{leg_h[:flight_number]} - #{time_key.to_s.sub('local_', '').gsub('_', ' ').titleize} must match: YYYY-MM-DD HH:MM (A|P)M"
                    end
                  end
                end
              end
            end

            raise errors.join("\n") if errors.present?

            whitelisted
          end

          def whitelisted_flight_schedule_params
            params.
              require(:flight_schedule).
              permit(
                :id,
                :pnr,
                :carrier_pnr,
                :operator,
                :original_value,
                :parent_schedule_id,
                :amount,
                :seats_reserved,
                :names_assigned,
                :booking_reference,
                :rtaxr,
                legs_attributes: [
                  :id,
                  :flight_number,
                  :local_departing_at,
                  :local_arriving_at,
                  :departing_airport_code,
                  :arriving_airport_code,
                  :is_subsidiary,
                  :_destroy
                ]
              )
          end
      end
    end
  end
end
