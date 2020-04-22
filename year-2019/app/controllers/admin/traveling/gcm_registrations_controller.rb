# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class GCMRegistrationsController < Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            filter, options = filter_records(amount_regex: /total_payments/) do |position|
              position.after do |prefix, param, value, options, not_like, separator|
                case true
                when !!((param.to_s =~ /category/) && (value.to_s =~ /supporter/i))
                  options[:filter] << "#{separator}(category_type IS NULL)"
                  options
                when !!(param.to_s =~ /has_passport/)
                  options[:filter] << "#{separator}(#{Boolean.parse(value) ? '' : ' NOT'}#{pp_exists})"
                  options
                when !!(param.to_s =~ /travelers|cancels/)
                  options[:filter] << "#{separator}(cancel_date IS#{(param.to_s =~ /^c/) ? ' NOT' : ''} NULL)"
                  options
                else
                  false
                end
              end
            end

            base_registrations = registrations_list

            base_registrations =
              filter ?
                base_registrations.where(filter, options.deep_symbolize_keys) :
                base_registrations

            registrations = base_registrations.order(*get_sort_params).offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_registrations.count('1')
              deflator.stream true, :registrations, '['

              i = 0
              registrations.each do |reg|
                deflator.stream (i += 1) > 1, nil, {
                  birth_date: reg[:birth_date]&.to_s,
                  cancel_date: reg[:cancel_date]&.to_s,
                  category_type: User.category_title(reg[:category_type]),
                  confirmation: reg[:confirmation],
                  dus_id: reg[:dus_id],
                  first: reg[:first],
                  first_payment_date: reg[:first_payment_date],
                  has_passport: reg[:has_passport],
                  last: reg[:last],
                  registered_date: reg[:registered_date],
                  total_payments: StoreAsInt::Money.new(reg[:total_payments]).to_s,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
          format.csv do
            @registrations = registrations_list

            render  csv: 'index',
                    filename: 'all_gcm_registrations',
                    with_time: true
          end
        end
      end

      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            raise "User Not Found" unless u = User.get(params[:id])
            return render json: {
              dus_id:             u.dus_id,
              first:              u.first,
              middle:             u.middle,
              last:               u.last,
              suffix:             u.suffix,
              gender:             u.gender,
              birth_date:         u.birth_date&.to_s,
              category_title:     u.category_title,
              shirt_size:         u.shirt_size,
              get_passport:       get_passport_link(u),
              first_payment_date: u.traveler&.first_payment_date,
              total_payments:     u.traveler&.total_payments&.to_s(true),
              team_name:          u.team&.name,
              cancel_date:        u.traveler&.cancel_date&.to_s,
              address:            u.main_address&.to_s,
              marathon_registration_attributes: {
                id: u.marathon_registration&.id,
                confirmation: u.marathon_registration&.confirmation,
                email: u.marathon_registration&.email || 'gcm-registrations@downundersports.com',
                registered_date: u.marathon_registration&.registered_date,
              }
            }
          end
        end
      rescue
        return not_authorized($!.message, 422)
      end

      def update
        return not_authorized("CANNOT ADD/REMOVE/MODIFY REGISTRATIONS IN PREVIOUS YEARS", 422)
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def whitelisted_filter_params
          params.permit(allowed_keys)
        end

        def whitelisted_marathon_params
          params.require(:user).permit(
            marathon_registration_attributes: %i[
              id
              confirmation
              email
              registered_date
              user_id
            ]
          )
        end

        def allowed_keys
          @allowed_keys ||= %i[
            birth_date
            cancel_date
            cancels
            category
            category_type
            confirmation
            dus_id
            first
            first_payment_date
            has_passport
            last
            registered_date
            total_payments
            travelers
          ].freeze
        end

        def default_sort_order
          %i[ first last ]
        end

        def param_to_col_name(param)
          param.to_s =~ /birth_date/ ? 'COALESCE(user_passports.birth_date, users.birth_date)' : super
        end

        def pp_exists
          '(EXISTS (SELECT 1 FROM user_passports WHERE user_passports.user_id = travelers.user_id))'
        end

        def registrations_list
          authorize Traveler.
            joins(:user, :team).
            joins("LEFT JOIN user_marathon_registrations marathon_registrations ON marathon_registrations.user_id = users.id").
            joins("LEFT JOIN user_passports ON user_passports.user_id = users.id").
            joins(
              <<-SQL.gsub(/\s*\n?\s+/m, ' ')
                INNER JOIN (
                  SELECT
                    traveler_id,
                    date(MIN(created_at) AT TIME ZONE 'MST') AS first_payment_date,
                    SUM(amount) AS total_payments
                  FROM
                    payment_items
                  GROUP BY
                    traveler_id
                ) traveler_payments ON traveler_payments.traveler_id = travelers.id
              SQL
            ).
            where("teams.sport_id = ?", Sport::XC.id).
            select(
              "traveler_payments.first_payment_date",
              "traveler_payments.total_payments",
              "users.dus_id",
              "users.first",
              "users.last",
              "users.category_type",
              "COALESCE(user_passports.birth_date, users.birth_date) AS birth_date",
              "(SELECT (#{pp_exists})) AS has_passport",
              "marathon_registrations.registered_date",
              "marathon_registrations.confirmation",
              "travelers.*",
            )
            # joins('LEFT JOIN user_marathon_registrations ON user_marathon_registrations.user_id = users.id').
            # select(
            #   'marathon_registrations.registered AS gcm_reg_date, marathon_registrations.confirmation AS gcm_confirmation, marathon_registrations.email AS gcm_email')
        end
    end
  end
end
