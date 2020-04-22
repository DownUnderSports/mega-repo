# encoding: utf-8
# frozen_string_literal: true

module API
  class NationalitiesController < API::ApplicationController
    def index
      if stale? last_modified: nations_last_modified
        @nationalities = User::Nationality.order(:code, :country).select(:id, :code, :country, :nationality)

        render json: @nationalities
      end
    end

    private
      def nations_last_modified
        User::Nationality.try(:maximum, :updated_at) || Time.zone.now
      end
  end
end
