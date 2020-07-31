# encoding: utf-8
# frozen_string_literal: true

module API
  class GenerateThankYouTicketsController < ::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    skip_before_action :verify_authenticity_token

    # == Actions ============================================================
    def create
      ThankYouTicket.transaction do
        u = User.find_by_dus_id_hash(params[:id])
        return render json: { errors: [ "Traveler not found" ] }, status: 404 unless u&.is_traveler?
        count = [ 1, params[:count].to_i ].max
        tickets = []
        count.times do
          tickets << ThankYouTicket.create!(user_id: u.id)
        end
        return render json: { tickets: tickets.as_json(host: request.base_url) }
      end
    rescue
      return render json: { errors: [ $!.message ] }, status: 500
    end

    def show
      respond_to do |format|
        format.html do
          return head 500 unless lookup_ids
          opts = {
            html: "thank_you_tickets_#{Time.zone.now.to_s.gsub(/[^a-z0-9]/, "_")}",
            template: "api/generate_thank_you_tickets/show.html.erb",
            layout: false,
          }
          if Boolean.parse(params[:for_print])
            return send_data render_to_string(**opts.except(:html).merge(action: :show)), filename: "#{opts[:html]}.html", content_type: "application/html"
          else
            return render **opts
          end
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def lookup_ids
        return @tickets if @tickets.present?
        @user ||= User.find_by_dus_id_hash(params[:id])
        return nil unless @user && @user.is_traveler?
        @tickets = ThankYouTicket.where(id: params[:ids])
      end
  end
end
