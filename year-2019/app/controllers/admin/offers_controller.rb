# encoding: utf-8
# frozen_string_literal: true

module Admin
  class OffersController < Admin::ApplicationController
    # == Modules ============================================================
    include Packageable

    # == Class Methods ======================================================
    before_action :lookup_user, except: [ :index ]

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      return not_authorized("CANNOT ADD/REMOVE/MODIFY OFFERS IN PREVIOUS YEARS", 422)
    end

    def destroy
      return create
    end

    def update
      return create
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          offer = authorize Traveler::Offer.includes(:traveler, :assigner).find_by(id: params[:id])

          render json: offer_json(offer), status: 200
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Offer not found',
        $!.message
      ], 422)
    end

    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          lookup_user if params[:user_id].present?

          offers = authorize (@found_user ? @found_user.offers : Traveler::Offer).includes(:traveler, :assigner).order(:name, :amount)

          if stale? offers
            render json: {
              offers: offers.map {|d| offer_json(d) }
            }
          end
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Invalid',
        $!.message
      ], 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def whitelisted_offer_params
        return @whitelisted_offer_params if @whitelisted_offer_params
        @whitelisted_offer_params = all_offer_params.permit(:amount, :name, :description, :assigner_id, :minimum, :maximum, :expiration_date, rules: [])
        if all_offer_params[:created_at_override].present?
          cr_time = Time.zone.parse(all_offer_params[:created_at_override]).midnight + 2.hours
          @whitelisted_offer_params[:created_at] = cr_time unless @offer && (@offer.created_at.to_date == cr_time)
        end
        puts @whitelisted_offer_params
        @whitelisted_offer_params
      end

      def all_offer_params
        params.require(:offer)
      end

  end
end
