# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class EventResultsController < Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            filter, options = filter_records

            base_event_results =
              filter ?
                event_results_list.where(filter, options.deep_symbolize_keys) :
                event_results_list

            event_results = base_event_results.
              order(*get_sort_params, :name, :sport_abbr, :id).
              offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_event_results.count('1')
              deflator.stream true, :event_results, '['

              i = 0
              event_results.each do |event_result|
                deflator.stream (i += 1) > 1, nil, {
                  id:         event_result.id,
                  name:       event_result.name,
                  sport_abbr: event_result.sport_abbr,
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
            @event_result ||= EventResult.find(params[:id])

            render json: {
              id:         @event_result.id,
              name:       @event_result.name,
              sport_id:   @event_result.sport_id,
              static_ids: @event_result.static_files.pluck(:id),
            }.null_to_str
          end
        end
      rescue NoMethodError
        return not_authorized([
          'Competing Team not found',
          $!.message
        ], 422)
      end

      def new
        @event_result = EventResult.new
        return show
      end

      def create
        run_an_api_action do
          EventResult.create!(whitelisted_event_result_params)
        end
      end

      def update
        run_an_api_action do
          (r = EventResult.find(params[:id])).update!(whitelisted_event_result_params)

          r
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def allowed_keys
        @allowed_keys ||= [
          :id,
          :name,
          :sport_abbr,
        ].freeze
      end

      def event_results_list
        EventResult.
          joins(
            <<-SQL.cleanup_production
              INNER JOIN (
                SELECT
                  id,
                  abbr_gender AS sport_abbr
                FROM
                  sports
              ) sports
                ON sports.id = event_results.sport_id
            SQL
          ).
          select(
            "event_results.*",
            "sports.sport_abbr"
          )
      end

      def get_event_result
        raise "Event Result Not Found" unless r = authorize(EventResult.find(params[:id]))
        r
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def whitelisted_event_result_params
        params.require(:event_result).
          permit(
            :id,
            :sport_id,
            :name,
            # email attrs, only on update
            :description,
            :email,
            :subject,
          )
      end
    end
  end
end
