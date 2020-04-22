# encoding: utf-8
# frozen_string_literal: true

module Packageable
  extend ActiveSupport::Concern

  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================

  # == Actions ============================================================
  def index
    return show if params[:base_debit_id].present?
    lookup_user if params[:user_id].present?

    respond_to do |format|
      format.html { fallback_index_html }
      format.json do
        credits = authorize (@found_user ? @found_user.credits : Traveler::Credit).includes(:traveler, :assigner).order(:name, :amount)
        debits = authorize (@found_user ? @found_user.debits : Traveler::Debit).includes(:traveler, :base_debit, :assigner).order(:name, :amount)
        offers = authorize (@found_user ? @found_user.offers : Traveler::Offer).includes(:traveler, :assigner).order(:name, :amount)

        last_modified = [
          credits.try(:maximum, :updated_at),
          debits.try(:maximum, :updated_at),
          offers.try(:maximum, :updated_at)
        ].select(&:present?).max

        if !last_modified || stale?(etag: last_modified, last_modified: last_modified)
          render json: {
            credit_categories: credit_categories,
            credits: credits.map {|d| credit_json(d) },
            debits: debits.map {|d| debit_json(d) },
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
    def lookup_user
      @found_user = User.get(params[:user_id]) if params[:user_id].present?
    end

    def category_description(name)
      Traveler::Credit.category_description(name)
    end

    def credit_categories
      Traveler::Credit.categories.map do |cr|
        cr.as_json.deep_symbolize_keys.merge(largest: cr.largest&.cents&.to_s(true), smallest: cr.smallest.cents&.to_s(true), description: category_description(cr.name))
      end
    end

    def credit_json(credit)
      {
        id: credit.id,
        dus_id: credit.traveler.user.dus_id,
        user: credit.traveler.user.full_name,
        assigner: credit.assigner&.full_name,
        name: credit.name,
        description: credit.description,
        amount: credit.amount,
        add_date: credit.created_at&.to_date
      }.null_to_str
    end

    def debit_json(debit)
      {
        id: debit.id,
        base_debit_id: debit.base_debit_id,
        base_debit: debit.base_debit&.attributes,
        dus_id: debit.traveler.user.dus_id,
        user: debit.traveler.user.full_name,
        assigner: debit.assigner&.print_names,
        name: debit.name,
        description: debit.description,
        amount: debit.amount,
        add_date: debit.created_at&.to_date
      }.null_to_str
    end

    def offer_json(offer)
      {
        id: offer.id,
        dus_id: offer.user.dus_id,
        user: offer.user.full_name,
        assigner: offer.assigner&.full_name,
        name: offer.name,
        description: offer.description,
        amount: offer.amount,
        minimum: offer.minimum,
        maximum: offer.maximum,
        expiration_date: offer.expiration_date,
        rules: offer.rules,
        rule: offer.rule.titleize,
        add_date: offer.created_at&.to_date
      }.null_to_str
    end
end
