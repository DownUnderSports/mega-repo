# encoding: utf-8
# frozen_string_literal: true

module Admin
  class PrintPacketsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'standalone'

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index ]

    # == Actions ============================================================
    def index
      expires_now

      respond_to do |format|
        format.html do
        end
        format.csv do
          render  csv: "all_travelers",
                  filename: "all_travelers",
                  with_time: true
        end
        format.any do
          return redirect_to admin_print_packets_path(format: :html), status: 303
        end
      end
    end

    def travel_card
      return get_next_user_or_render(:travel_card_admin_print_packet_path, 'card')
    end

    def travel_page
      return get_next_user_or_render(:travel_page_admin_print_packet_path)
    end

    def get_sheet
      get_travelers

      return render csv: "get_sheet", filename: "packet_names_list", with_time: true, handlers: [:csvrb], formats: [:csv]
    end

    def teammates
      return get_next_user_or_render(:teammates_admin_print_packet_path)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    def lookup_user
      @found_user = User.get(params[:id])
    end

    private
      def get_travelers
        @direct_print = true
        expires_now
        query = begin
          JSON.parse(params[:query].presence)
        rescue
          params[:query].presence || '1=1'
        end

        order = Arel.sql('COALESCE(travelers.departing_date, teams.departing_date) ASC, travelers.user_id ASC')

        @travelers = Traveler.active.
            joins(:user, :team).
            where(query, *(params[:query_args].presence || []))

        if params[:only_ids].present?
          @travelers = @travelers.
            where(user_id: params[:only_ids].map {|i| User[i]&.id }.select(&:present?))
        end

        if params[:exclude_ids].present?
          @travelers = @travelers.
            where.not(user_id: params[:exclude_ids].map {|i| User[i]&.id }.select(&:present?))
        end

        if params[:bus_id] == "NONE"
          @travelers = @travelers.where(
            <<-SQL.cleanup_production
              (
                NOT
                  (
                    EXISTS
                      (
                        SELECT
                          1
                        FROM
                          traveler_buses
                        INNER JOIN traveler_buses_travelers
                          ON traveler_buses.id = traveler_buses_travelers.bus_id
                        WHERE
                          (
                            (traveler_buses_travelers.traveler_id = travelers.id)
                            AND
                            (traveler_buses.sport_id = teams.sport_id)
                          )

                      )
                  )
              )
            SQL
          )
        elsif params[:bus_id].present?
          @travelers = @travelers.where_exists(:buses, id: params[:bus_id])
        end

        @travelers = @travelers.
          select(
            :id,
            "LAG(user_id) over (ORDER BY #{order}) AS prev_id",
            "LEAD(user_id) over (ORDER BY #{order}) AS next_id"
          )

        @travelers = Traveler.joins(
          <<-SQL.gsub(/\s*\n?\s+/m, ' ')
            INNER JOIN (
              SELECT
                id AS traveler_id,
                prev_id,
                next_id
              FROM
                ( #{ @travelers.to_sql } ) inner_lag_lead
            ) lag_lead
              ON lag_lead.traveler_id = travelers.id
          SQL
        ).select(:id, :user_id, 'lag_lead.*')
      end

      def get_file_name
        b_name = @found_user.bus&.underscored || "#{@found_user.team.sport.abbr_gender}_NONE"
        "#{b_name}_#{action_name}_#{@found_user&.dus_id}_#{Time.now.to_s(:db).gsub(/\s/, '_')}"
      end

      def get_next_user_or_render(path_method, layout = nil)
        expires_now

        if Boolean.parse(params[:direct_print])
          q = get_travelers

          next_user = @found_user ? q.find_by(user_id: @found_user.id)&.next_id : q.find_by(lag_lead: { prev_id: nil })&.user_id

          @next_user = next_user \
            ? __send__(path_method, next_user, direct_print: 1, bus_id: params[:bus_id].presence, query: params[:query].presence, query_args: params[:query_args].presence, only_ids: params[:only_ids].presence, exclude_ids: params[:exclude_ids].presence) \
            : admin_print_packets_path(format: :html)

          return redirect_to @next_user, status: 303 unless @found_user
        end

        return redirect_to admin_print_packets_path(format: :html), status: 303 unless @found_user

        @title = get_file_name

        options = {
          pdf: @title, show_as_html: true, formats: :pdf
        }

        options[:layout] = layout if layout.present?

        return render options
      end

  end
end
