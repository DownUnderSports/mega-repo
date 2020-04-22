# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class EventRegistrationsController < Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            filter, options = filter_records(boolean_regex: /has_/)

            base_event_registrations =
              filter ?
                event_registrations_list.where(filter, options.deep_symbolize_keys) :
                event_registrations_list

            event_registrations = base_event_registrations.
              order(*get_sort_params, :dus_id, :id).
              offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_event_registrations.count('1')
              deflator.stream true, :event_registrations, '['

              i = 0
              event_registrations.each do |event_registration|
                deflator.stream (i += 1) > 1, nil, {
                  id:                       event_registration.id,
                  departing_date:           event_registration.departing_date,
                  dus_id:                   event_registration.dus_id,
                  first:                    event_registration.first,
                  has_four_hundred_m_relay: event_registration.has_four_hundred_m_relay.yes_no_to_s,
                  has_one_hundred_m_relay:  event_registration.has_one_hundred_m_relay.yes_no_to_s,
                  last:                     event_registration.last,
                  middle:                   event_registration.middle,
                  team_name:                event_registration.team_name,
                  total_events:             event_registration.total_events,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
          format.csv do
            render csv: 'index',
                   filename: 'user_event_registration_status',
                   with_time: true
          end
        end
      end

      def show
        return render json: get_event_registration.details(true)
      rescue
        return not_authorized([ $!.message ], 422)
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def allowed_keys
        @allowed_keys ||= [
          :id,
          :departing_date,
          :dus_id,
          :first,
          :has_four_hundred_m_relay,
          :has_one_hundred_m_relay,
          :last,
          :middle,
          :team_name,
          :total_events,
        ].freeze
      end

      def get_event_registration(skip_check = false)
        raise "User Not Found" unless u = User.get(params[:id])

        authorize u

        raise "Event Registration Not Submitted" unless u.event_registration

        u.event_registration
      end

      def event_registrations_list
        User::EventRegistration.
          joins(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              INNER JOIN (
                SELECT
                  user_event_registrations.id AS inner_event_registration_id,
                  (
                    CASE
                    WHEN
                      ( user_event_registrations.one_hundred_m_relay IS NULL )
                    THEN FALSE
                    ELSE TRUE
                    END
                  ) AS has_one_hundred_m_relay,
                  (
                    CASE
                    WHEN
                      ( user_event_registrations.four_hundred_m_relay IS NULL )
                    THEN FALSE
                    ELSE TRUE
                    END
                  ) AS has_four_hundred_m_relay,
                  (
                    COALESCE(event_100_m_count, 0) +
                    COALESCE(event_200_m_count, 0) +
                    COALESCE(event_400_m_count, 0) +
                    COALESCE(event_800_m_count, 0) +
                    COALESCE(event_1500_m_count, 0) +
                    COALESCE(event_3000_m_count, 0) +
                    COALESCE(event_90_m_hurdles_count, 0) +
                    COALESCE(event_100_m_hurdles_count, 0) +
                    COALESCE(event_110_m_hurdles_count, 0) +
                    COALESCE(event_200_m_hurdles_count, 0) +
                    COALESCE(event_300_m_hurdles_count, 0) +
                    COALESCE(event_400_m_hurdles_count, 0) +
                    COALESCE(event_2000_m_steeple_count, 0) +
                    COALESCE(event_long_jump_count, 0) +
                    COALESCE(event_triple_jump_count, 0) +
                    COALESCE(event_high_jump_count, 0) +
                    COALESCE(event_pole_vault_count, 0) +
                    COALESCE(event_shot_put_count, 0) +
                    COALESCE(event_discus_count, 0) +
                    COALESCE(event_javelin_count, 0) +
                    COALESCE(event_hammer_count, 0) +
                    COALESCE(event_3000_m_walk_count, 0) +
                    COALESCE(event_5000_m_walk_count, 0)
                  ) AS total_events,
                  event_registration_user.dus_id,
                  event_registration_user.first,
                  event_registration_user.middle,
                  event_registration_user.last,
                  event_registration_user.departing_date,
                  event_registration_user.team_name
                FROM
                  user_event_registrations
                INNER JOIN (
                  SELECT
                    users.id,
                    users.dus_id,
                    users.first,
                    users.middle,
                    users.last,
                    COALESCE(travelers.departing_date, teams.departing_date) AS departing_date,
                    teams.name AS team_name
                  FROM
                    users
                  LEFT JOIN travelers
                    ON travelers.user_id = users.id
                  LEFT JOIN teams
                    ON teams.id = travelers.team_id
                ) event_registration_user ON event_registration_user.id = user_event_registrations.user_id
              ) event_registration_info ON event_registration_info.inner_event_registration_id = user_event_registrations.id
            SQL
          ).
          select(
            'user_event_registrations.id',
            'event_registration_info.total_events',
            'event_registration_info.dus_id',
            'event_registration_info.first',
            'event_registration_info.middle',
            'event_registration_info.last',
            'event_registration_info.departing_date',
            'event_registration_info.team_name',
            'event_registration_info.has_one_hundred_m_relay',
            'event_registration_info.has_four_hundred_m_relay',
          )
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end
    end
  end
end
