# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class UsersController < ::Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            base_users = users_list

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

            base_users =
              authorize filter ?
                base_users.where(filter, options.deep_symbolize_keys) :
                base_users

            users = base_users.
              order(*get_sort_params, :first, :last, :id).
              offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_users.count('1')
              deflator.stream true, :users, '['

              i = 0
              users.each do |u|
                main_user_category = u.main_relation(skip_staff: true)&.category

                deflator.stream (i += 1) > 1, nil, {
                  cancel_date: u.cancel_date,
                  category_id: u.category_id,
                  category_type: u.category_title,
                  contactable: (u.interest_id < no_interest) && !(main_user_category&.wrong_school?),
                  current_balance: u.current_balance.cents.to_s(1),
                  departing_date: u.departing_date,
                  dus_id: u.dus_id,
                  email: u.email,
                  first: u.first,
                  gender: u.gender,
                  id: u.id,
                  joined_at: u.joined_at&.in_time_zone&.to_date,
                  last: u.last,
                  middle: u.middle,
                  phone: u.phone,
                  sport_abbr: u.sport_abbr,
                  state_abbr: u.state_abbr,
                  suffix: u.suffix,
                  total_charges: u.total_charges.cents.to_s(1),
                  total_credited: u.total_credited.cents.to_s(1),
                  total_debited: u.total_debited.cents.to_s(1),
                  total_paid: u.total_paid.cents.to_s(1),
                  traveling: u.traveler_id.present?,
                  url: u.admin_url,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================

      private
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
end
