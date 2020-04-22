# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class StaticFilesController < Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def show
        @file ||= event_result.static_files.find_by(id: params[:id])

        render json: {
          id:              @file.id,
          event_result_id: @file.event_result_id,
          name:            @file.name,
          link:            (@file.result_file.attached?) \
                             ? rails_blob_path(@file.result_file, expires_in: 1.hour, disposition: :inline)
                             : '',
        }.null_to_str
      rescue NoMethodError
        puts $!.message
        puts $!.backtrace
        return not_authorized([
          'Static File not found',
          $!.message
        ], 422)
      end

      def new
        @file = event_result.static_files.build
        return show
      end

      def create
        run_an_api_action do
          event_result.static_files.create!(whitelisted_static_file_params)
        end
      end

      def update
        run_an_api_action do
          f = event_result.static_files.find(params[:id])
          f.update!(whitelisted_static_file_params)
          f
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def event_result
        @event_result ||= EventResult.find(params[:event_result_id])
      end


      def whitelisted_static_file_params
        params.require(:static_file).
          permit(
            :id,
            :name,
            :result_file,
          ).to_h.symbolize_keys.merge({ name: params[:static_file][:name].presence || params[:name].presence })
      end
    end
  end
end
