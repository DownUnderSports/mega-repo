# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class PassportsController < ::Admin::ApplicationController
      # == Modules ============================================================
      include Filterable
      include Passportable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def eta_values
        pp = get_passport(true)

        return render json: pp.eta_values
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            filter, options = filter_records(boolean_regex: /has_|extra_/)

            base_passports =
              filter ?
                passports_list.where(filter, options.deep_symbolize_keys) :
                passports_list

            passports = base_passports.
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

              deflator.stream false, :total, base_passports.count('1')
              deflator.stream true, :passports, '['

              i = 0
              passports.each do |passport|
                deflator.stream (i += 1) > 1, nil, {
                  id:                   passport.id,
                  departing_date:       passport.departing_date,
                  dus_id:               passport.dus_id,
                  extra_eta_processing: passport.extra_eta_processing.yes_no_to_s,
                  first_checker_name:   passport.first_checker_name,
                  has_eta:              passport.has_eta.yes_no_to_s,
                  second_checker_name:  passport.second_checker_name,
                  team_name:            passport.team_name,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
          format.csv do
            render csv: 'index',
                   filename: 'user_passport_status',
                   with_time: true
          end
        end
      end

      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.any do
            pp = get_passport

            return render json: {
              has_questions_answered: true,
              needs_image: false,
              link: get_passport_link(pp.user)
            }
          end
        end
      rescue
        return not_authorized([ $!.message ], 422)
      end

      def create
        return update
      end

      def update
        pp = get_passport
        pp.verify!(whitelisted_passport_params.to_h)

        if pp.checker_id.present?
          pp.second_checker = current_user
        else
          pp.checker = current_user
        end

        pp.save!

        return render json: { message: 'ok' }, status: 200
      rescue
        puts $!.message
        puts $!.backtrace
        return render json: { errors: [ $!.message ] }, status: 200
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def allowed_keys
        @allowed_keys ||= [
          :departing_date,
          :dus_id,
          :extra_eta_processing,
          :first_checker_name,
          :has_eta,
          :second_checker_name,
          :team_name
        ].freeze
      end

      def get_passport(skip_check = false)
        raise "User Not Found" unless u = User.get(params[:user_id])

        authorize u

        raise "Passport Not Submitted" unless u.passport

        raise "Passport Not Ready" unless !!(u.passport.has_all_questions_answered?) \
                                          && u.passport.image.attached?

        raise "Can't Check Same Passport Twice" if  !skip_check \
                                                    && (
                                                      (u.passport.checker_id == current_user.id) \
                                                      || (u.passport.second_checker_id == current_user.id)
                                                    )

        u.passport
      end

      def passports_list
        show_all = !Boolean.parse(params[:has_eta]).nil? \
          || !Boolean.parse(params[:extra_eta_processing]).nil?

        User::Passport.
          joins(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              INNER JOIN (
                SELECT
                  user_passports.id AS inner_passport_id,
                  passport_user.dus_id,
                  passport_user.departing_date,
                  passport_user.team_name,
                  passport_first_checker.full_name AS first_checker_name,
                  passport_second_checker.full_name AS second_checker_name,
                  EXISTS (
                    SELECT
                      1
                    FROM
                      active_storage_attachments
                    WHERE
                      (active_storage_attachments.record_id = user_passports.id)
                      AND
                      (active_storage_attachments.record_type IN ('User::Passport','user_passports'))
                      AND
                      (active_storage_attachments.name = 'eta_proofs')
                      AND
                      (
                        EXISTS (
                          SELECT
                            1
                          FROM
                            active_storage_blobs
                          WHERE
                            (
                              active_storage_attachments.blob_id = active_storage_blobs.id
                            )
                        )
                      )
                  ) AS has_eta
                FROM
                  user_passports
                INNER JOIN (
                  SELECT
                    users.id,
                    users.dus_id,
                    COALESCE(travelers.departing_date, teams.departing_date) AS departing_date,
                    teams.name AS team_name
                  FROM
                    users
                  LEFT JOIN travelers
                    ON travelers.user_id = users.id
                  LEFT JOIN teams
                    ON teams.id = travelers.team_id
                ) passport_user ON passport_user.id = user_passports.user_id
                LEFT JOIN (
                  SELECT
                    users.id,
                    users.first || ' ' || users.last AS full_name
                  FROM
                    users
                ) passport_first_checker ON passport_first_checker.id = user_passports.checker_id
                LEFT JOIN (
                  SELECT
                    users.id,
                    users.first || ' ' || users.last AS full_name
                  FROM
                    users
                ) passport_second_checker ON passport_second_checker.id = user_passports.second_checker_id
              ) passport_info ON passport_info.inner_passport_id = user_passports.id
            SQL
          ).
          where(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              ( NOT ( user_passports.has_aliases = 'U' ) )
              AND
              ( NOT ( user_passports.has_convictions = 'U' ) )
              AND
              ( NOT ( user_passports.has_multiple_citizenships = 'U' ) )
            SQL
          ).
          where(%Q((user_passports.checker_id IS DISTINCT FROM ?) OR ?), current_user.id, show_all).
          where(%Q((user_passports.second_checker_id IS NULL) OR ?), show_all).
          select(
            "user_passports.*",
            "passport_info.dus_id",
            "passport_info.departing_date",
            "passport_info.has_eta",
            "passport_info.team_name",
            "passport_info.first_checker_name",
            "passport_info.second_checker_name",
          )
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end
    end
  end
end
