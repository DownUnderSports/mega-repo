# encoding: utf-8
# frozen_string_literal: true

module API
  class RefundsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      raise "User Not Found" unless user = User.find_by_dus_id_hash(params[:user_id])

      str = whitelisted_refund_params.to_json.to_b64
      value = encrypt_and_encode_str(str)

      raise "Failed to encrypt submission" unless str == decrypt_gpg_base64(value)&.first

      user.refund_requests.create!(value: value)

      return render json: { message: 'ok' }, status: 200
    rescue
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def whitelisted_refund_params
        params.require(:refund).
          permit(
            :routing_number,
            :account_number,
            billing: [
              :company,
              :country_code_alpha3,
              :extended_address,
              :name,
              :phone,
              :email,
              :locality,
              :postal_code,
              :region,
              :street_address,
            ],
          )
      end

  end
end
