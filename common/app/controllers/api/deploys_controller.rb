# encoding: utf-8
# frozen_string_literal: true

module API
  class DeploysController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      return create
    end

    def create
      raise "Not Allowed" unless (params[:restart_id] == "as809q2AERaw89gh2k3j") && valid_heroku_request?
      Sidekiq::ProcessSet.new.each(&:quiet!) if quiet = should_quiet?
      return render json: { success: true, quieted: quiet }, status: 200
    rescue
      p $!.message
      return render json: { success: false, valid: valid_heroku_request?, errors: [ $!.message, $!.backtrace ] }, status: 200
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def valid_heroku_request?
        calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(
          OpenSSL::Digest.new('sha256'),
          Rails.application.credentials.dig(:heroku, :webhooks, :deploys),
          request.raw_post
        )).strip
        heroku_hmac = request.headers['Heroku-Webhook-Hmac-SHA256']

        heroku_hmac && Rack::Utils.secure_compare(calculated_hmac, heroku_hmac)
      rescue
        $!.message
      end

      def should_quiet?
        case params['resource']
        when 'release', 'build'
          params["data"].blank? ||
          (params["data"]["status"] == 'pending')
        else
          false
        end
      end

  end
end
