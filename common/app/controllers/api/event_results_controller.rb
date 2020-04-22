# encoding: utf-8
# frozen_string_literal: true

module API
  class EventResultsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      sports = Sport.where(id: Sport[params[:id]]&.id).
        or(Sport.where(abbr: params[:id]&.upcase))

      results = EventResult.where(sport_id: sports.select(:id))

      if !results.size || stale?(results)
        results = EventResult.where(sport_id: sports.select(:id)).
          map do |er|
            er.
              as_json(include: :sport).
              merge(
                static_files: (
                  er.static_files.map do |sf|
                    sf.result_file.attached? \
                      ? sf.as_json(include: :result_file_blob).
                          merge(
                            link: rails_blob_url(
                              sf.result_file,
                              expires_in: 1.year,
                              disposition: :inline
                            ),
                            attachment_link: rails_blob_url(
                              sf.result_file,
                              expires_in: 1.year,
                              disposition: :attachment
                            )
                          ) \
                      : nil
                  end.select(&:present?)
                )
              )
          end

        render json: { results: results }
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def lookup_user
        @user ||= User.find_by_dus_id_hash(params[:dus_id_hash])
        unless @user && @user.traveler
          request.format = :html
        end
        @user
      end

  end
end
