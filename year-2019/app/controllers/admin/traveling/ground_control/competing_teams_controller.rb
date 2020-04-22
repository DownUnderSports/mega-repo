# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    module GroundControl
      class CompetingTeamsController < Admin::ApplicationController
        # == Modules ============================================================
        include Filterable

        # == Class Methods ======================================================

        # == Pre/Post Flight Checks =============================================

        # == Actions ============================================================
        def index
          respond_to do |format|
            format.html { fallback_index_html }
            format.json do
              base_competing_teams = competing_teams_list

              filter, options = filter_records

              base_competing_teams =
                filter ?
                  base_competing_teams.where(filter, options.deep_symbolize_keys) :
                  base_competing_teams

              competing_teams = base_competing_teams.
                order(*get_sort_params, :sport_abbr, :name).
                offset((params[:page] || 0).to_i * 100).limit(100)

              headers["X-Accel-Buffering"] = 'no'

              expires_now
              headers["Content-Type"]        = "application/json; charset=utf-8"
              headers["Content-Disposition"] = 'inline'
              headers["Content-Encoding"]    = 'deflate'
              headers["Last-Modified"]       = Time.zone.now.ctime.to_s

              self.response_body = Enumerator.new do |y|
                deflator = StreamJSONDeflator.new(y)

                deflator.stream false, :total, base_competing_teams.count('1')
                deflator.stream true, :competing_teams, '['

                i = 0
                competing_teams.each do |competing_team|
                  deflator.stream (i += 1) > 1, nil, {
                    id:         competing_team.id,
                    assigned:   competing_team.assigned,
                    name:       competing_team.name,
                    letter:     competing_team.letter,
                    sport_abbr: competing_team.sport_abbr,
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
              @competing_team ||= CompetingTeam.find(params[:id])

              render json: {
                id:         @competing_team.id,
                name:       @competing_team.name,
                letter:     @competing_team.letter,
                sport_abbr: @competing_team.sport_abbr,
                sport_id:   @competing_team.sport_id,
                link:       url_with_auth(admin_traveling_ground_control_competing_team_path(@competing_team, format: :pdf))
              }.null_to_str
            end
            format.pdf do
              @competing_team ||= CompetingTeam.find(params[:id])

              render pdf: "#{@competing_team.sport.full_gender} Roster - #{@competing_team.name} - #{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
            end
            format.csv do
              @competing_team ||= CompetingTeam.find(params[:id])

              return render csv: "competing_team",
                     template: 'admin/traveling/ground_control/competing_teams/show',
                     filename: "#{@competing_team.to_str} Roster",
                     with_time: true
            end
          end
        rescue NoMethodError
          return not_authorized([
            'Competing Team not found',
            $!.message
          ], 422)
        end

        def teammates
          @competing_team ||= CompetingTeam.find(params[:id])

          render pdf: "#{@competing_team.sport.full_gender} - #{@competing_team.name} Teammates - #{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true
        rescue NoMethodError
          return not_authorized([
            'Competing Team not found',
            $!.message
          ], 422)
        end

        def new
          @competing_team = CompetingTeam.new
          return show
        end

        def create
          run_an_api_action do
            CompetingTeam.create!(whitelisted_competing_team_params)
          end
        end

        def update
          run_an_api_action do
            (ct = CompetingTeam.find(params[:id])).update!(whitelisted_competing_team_params)

            ct
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
              :name,
              :letter,
              :sport_abbr,
            ].freeze
          end

          def default_sort_order
            []
          end

          def competing_teams_list
            CompetingTeam.
              joins(
                <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                  INNER JOIN (
                    SELECT
                      competing_teams.id AS competing_team_id,
                      COALESCE(traveler_counts.assigned, 0) AS assigned,
                      sport_info.sport_abbr
                    FROM
                      competing_teams
                    INNER JOIN (
                      SELECT
                        sports.id AS sport_id,
                        sports.abbr_gender AS sport_abbr
                      FROM
                        sports
                    ) sport_info
                      ON sport_info.sport_id = competing_teams.sport_id
                    LEFT JOIN (
                      SELECT
                        competing_team_id,
                        COUNT(traveler_id) AS assigned
                      FROM
                        competing_teams_travelers
                      WHERE
                        traveler_id IN (#{Traveler.active.select(:id).to_sql})
                      GROUP BY
                        competing_team_id
                    ) traveler_counts
                      ON traveler_counts.competing_team_id = competing_teams.id
                  ) team_info ON team_info.competing_team_id = competing_teams.id
                SQL
              ).
              select(
                "competing_teams.*",
                "team_info.assigned",
                "team_info.sport_abbr",
              )
          end

          def whitelisted_competing_team_params
            params.require(:competing_team).
              permit(
                :id,
                :sport_id,
                :name,
                :letter
              )
          end
      end
    end
  end
end
