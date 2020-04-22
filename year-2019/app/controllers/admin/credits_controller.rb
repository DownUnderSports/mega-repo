# encoding: utf-8
# frozen_string_literal: true

module Admin
  class CreditsController < Admin::ApplicationController
    # == Modules ============================================================
    include Packageable

    # == Class Methods ======================================================
    before_action :lookup_user, except: [ :index ]

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      credits = authorize @found_user.traveler.credits
      credit = credits.create!(**whitelisted_credit_params.to_h.deep_symbolize_keys, assigner_id: whitelisted_credit_params[:assigner_id] || current_user.id)
      return render json: credit_json(credit), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Credit', $!.message ], 422
    end

    def destroy
      credit = authorize Traveler::Credit.includes(:traveler, :assigner).find_by(id: params[:id])
      credit.destroy!
      return head 200
    rescue
      return not_authorized [ 'Failed to Remove Credit', $!.message ], 422
    end

    def update
      @credit = authorize @found_user.traveler.credits.find(params[:id])
      @credit && @credit.update!(whitelisted_credit_params)
      return render json: credit_json(@credit), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Credit', $!.message ], 422
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          credit = authorize Traveler::Credit.includes(:traveler, :assigner).find_by(id: params[:id])

          render json: credit_json(credit), status: 200 if stale? credit
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Credit not found',
        $!.message
      ], 422)
    end

    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          lookup_user if params[:user_id].present?

          credits = authorize (@found_user ? @found_user.credits : Traveler::Credit).includes(:traveler, :assigner).order(:name, :amount)

          render json: {
            credit_categories: credit_categories,
            credits: credits.map {|d| credit_json(d) },
          }
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
      def whitelisted_credit_params
        return @whitelisted_credit_params if @whitelisted_credit_params
        @whitelisted_credit_params = all_credit_params.permit(:amount, :name, :description, :assigner_id)
        if all_credit_params[:created_at_override].present?
          cr_time = Time.zone.parse(all_credit_params[:created_at_override]).midnight + 2.hours
          @whitelisted_credit_params[:created_at] = cr_time unless @credit && (@credit.created_at.to_date == cr_time)
        end
        @whitelisted_credit_params
      end

      def all_credit_params
        params.require(:credit)
      end

  end
end
