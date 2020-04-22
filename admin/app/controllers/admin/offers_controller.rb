# encoding: utf-8
# frozen_string_literal: true

module Admin
  class OffersController < ::Admin::ApplicationController
    # == Modules ============================================================
    include Packageable

    # == Class Methods ======================================================
    before_action :lookup_user, except: [ :index ]

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      offers = authorize @found_user.offers
      offer = offers.create!(**whitelisted_offer_params.to_h.deep_symbolize_keys, assigner_id: whitelisted_offer_params[:assigner_id] || current_user.id)
      return render json: offer_json(offer), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Offer', $!.message ], 422
    end

    def destroy
      offer = authorize Traveler::Offer.includes(:traveler, :assigner).find_by(id: params[:id])
      offer.destroy!
      return head 200
    rescue
      return not_authorized [ 'Failed to Remove Offer', $!.message ], 422
    end

    def update
      @offer = authorize @found_user.offers.find(params[:id])
      if @offer
        if params[:force_next].present? && Boolean.parse(params[:force_next])
          @offer.__send__ :next_rule
        else
          @offer.update!(**whitelisted_offer_params.to_h.deep_symbolize_keys, assigner_id: current_user&.id || auto_worker)
          begin
            @offer.user &&
            @offer.traveler &&
            Traveler::OffersCheckJob.perform_later(@offer.traveler_id)
          rescue
          end
        end
      end
      return render json: offer_json(@offer), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Offer', $!.message ], 422
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
