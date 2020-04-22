# encoding: utf-8
# frozen_string_literal: true

module Admin
  class PostcardsController < Admin::StatementsController
    # == Modules ============================================================
    include Filterable

    # == Class Methods ======================================================
    layout 'postcard'

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      return redirect_to next_user || '/admin/users', status: 303 if Boolean.parse(params[:continue])
      render 'index.html.erb', format: :html, layout: 'standalone'
    end

    def show
      if params[:add_mailing_category].present?
        return not_authorized("CANNOT CHANGE USERS IN PREVIOUS YEARS", 422)
      end

      render pdf: "address_postcard_#{Time.now.to_s(:db).gsub(/\s/, '_')}", layout: 'postcard', show_as_html: true
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def invalid_user
        @next_user && !@next_user.main_address
      end

      def travelers
        return @traveler_query if @traveler_query.present?
        filter, options = filter_records(amount_regex: /total_|_balance/) do |position|
          position.after do |prefix, param, value, options, not_like, separator|
            case true
            when !!((param.to_s =~ /category/) && (value.to_s =~ /supporter/i))
              options[:filter] << "#{separator}(category_type IS NULL)"
              options
            when !!(param.to_s =~ /travelers|cancels/)
              options[:filter] << "#{separator}(traveler_id IS NOT NULL) AND (cancel_date IS#{(param.to_s =~ /^c/) ? ' NOT' : ''} NULL)"
              options
            when !!(param.to_s =~ /wrong_school/)
              options[:filter] << "#{separator}(school_id = :#{prefix}wrong_school_id)"
              options["#{prefix}wrong_school_id"] = wrong_school&.id
              options
            else
              false
            end
          end
        end

        base = ::Accounting::Views::User.all

        if filter.present?
          base = base.where(filter, options.deep_symbolize_keys)
        end

        params[:exclude_mailings] = [] unless params[:exclude_mailings].is_a?(Array)
        params[:include_mailings] = [] unless params[:include_mailings].is_a?(Array)

        if params[:exclude_mailings].present?
          base = base.where.not(id: User.where_exists(:mailings, category: params[:exclude_mailings]))
        end

        if params[:include_mailings].present?
          params[:include_mailings].each do |v|
            base = base.where(id: User.where_exists(:mailings, category: v))
          end
        end

        @traveler_query = super.where(user_id: base.select(:id))
      end

      def get_next_path
        admin_postcard_path(
          @next_user.dus_id,
          direct_print:     1,
          include_mailings:     params[:include_mailings].presence || [],
          exclude_mailings:     params[:exclude_mailings].presence || [],
          add_mailing_sent:     params[:add_mailing_sent].presence,
          add_mailing_category: params[:add_mailing_category].presence,
          **whitelisted_filter_params.to_h.deep_symbolize_keys
        )
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def allowed_keys
        @allowed_keys ||= [
          :cancel_date,
          :cancels,
          :category_type,
          :current_balance,
          :departing_date,
          :dus_id,
          :email,
          :first,
          :gender,
          :joined_at,
          :last,
          :middle,
          :phone,
          :sport_abbr,
          :state_abbr,
          :suffix,
          :total_debited,
          :total_charges,
          :total_credited,
          :total_paid,
          :travelers,
          :wrong_school,
        ].freeze
      end

      def default_sort_order
        []
      end

      def users_list
        ::Accounting::Views::User.all
      end
  end
end
