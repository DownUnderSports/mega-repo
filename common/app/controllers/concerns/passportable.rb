# encoding: utf-8
# frozen_string_literal: true

module Passportable
  extend ActiveSupport::Concern

  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================

  # == Actions ============================================================

  # == Cleanup ============================================================

  # == Utilities ==========================================================

  private
    def whitelisted_passport_visa_params
      params.require(:passport).permit(
        :has_multiple_citizenships,
        :has_aliases,
        :has_convictions,
        convictions_array: [],
        citizenships_array: [],
        aliases_array: []
      )
    end

    def whitelisted_passport_params
      params.require(:passport).permit(
        :type,
        :code,
        :nationality,
        :authority,
        :number,
        :surname,
        :given_names,
        :sex,
        :birthplace,
        :birth_date,
        :issued_date,
        :expiration_date,
        :country_of_birth,
        :has_multiple_citizenships,
        :has_aliases,
        :has_convictions,
        convictions_array: [],
        citizenships_array: [],
        aliases_array: []
      )
    rescue
      {}
    end

    def whitelisted_direct_passport_params
      params.require(:signed_upload).permit(:image)
    rescue
      nil
    end

    def whitelisted_passport_upload_params
      params.require(:upload).permit(:io, :filename, :content_type, :identify)
    rescue
      {}
    end
end
