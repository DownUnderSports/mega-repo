# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ApplicationController < ::ApplicationController
    # == Modules ============================================================
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include BetterRecord::Authenticatable
    include Pundit

    # == Class Methods ======================================================
    def self.not_authorized_error
      Pundit::NotAuthorizedError
    end

    def self.not_defined_error
      Pundit::NotDefinedError
    end

    # == Pre/Post Flight Checks =============================================
    skip_before_action :verify_authenticity_token
    skip_before_action :check_user
    before_action :header_hash
    before_action :verify_user_access
    skip_before_action :verify_user_access, only: [ :serve_asset, :whats_my_url ]
    # after_action :set_auth_header

    # == Actions ============================================================
    def temp
      respond_to do |format|
        format.csv do
          path = tmp_csv_download params[:file_name].to_s
          return head 500 unless File.file?(path)

          csv_headers(params[:file_name].to_s.presence || 'download-temp.csv', modified: File.mtime(path).to_s)

          return send_file path,
            type: response.headers['Content-Type'],
            disposition: 'attachment',
            filename: params[:file_name].to_s.presence || 'download-temp.csv'
        end
      end
    end

    def whats_my_url
      headers["X-Accel-Buffering"] = 'no'

      expires_now
      headers["Content-Type"] = "text/plain; charset=utf-8"
      headers["Content-Disposition"] = 'inline'
      headers["Last-Modified"] = Time.zone.now.ctime.to_s

      return render plain: <<-STRING.strip.sub(/authorize.(admin|auth(orize|enticate))/, "authorize")
        #{
          request.protocol
        }authorize.#{
          request.host_with_port
        }/admin/authentication?device_id=#{
          requesting_device_id
        }
      STRING
    end

    # == Cleanup ============================================================
    rescue_from not_authorized_error, with: :not_authorized
    rescue_from not_defined_error, with: :record_not_found

    if (ENV['CURRENT_APP_NAME'].to_s == 'downundersports-admin') || Rails.env.development?
      layout 'admin'
    else
      before_action :unauthorized_access
    end

    if Rails.env.development?
      def requesting_device_id
        "development"
      end

      def get_dev_user
        BetterRecord::Current.user ||= \
          User.joins(:staff).where(first: 'Sampson', staffs: { admin: true }).limit(1).take \
          || User.joins(:staff).limit(1).take \
          || User.new(category: Staff.new(admin: true))
      end

      def current_user(*args)
        unless BetterRecord::Current.user
          self.current_token = create_jwt(get_dev_user)
          set_user get_dev_user
        end

        BetterRecord::Current.user = User[BetterRecord::Current.user.id]

        set_current_user_cookies

        BetterRecord::Current.user
      end
    end

    def fallback_index_html
      @disallow_ssr_render_caching = 1
      super
    end

    # == Utilities ==========================================================
    private
      def default_sort_order
        [ :id ]
      end

      def direction_maps
        {}
      end

      def allowed_keys
        []
      end

      def get_sort_params
        sort = params[:sort].present? &&
          (
            params[:sort].
              select {|k| (direction_maps.present? ? direction_maps.keys : allowed_keys).include?(k.to_sym) }.
              map do |k|
                "#{direction_maps[k.to_sym] || k.to_sym} #{(params[:directions][k].presence || 'asc').to_sym}"
              end
          )

        sort.present? ? sort : default_sort_order
      end

      def unauthorized_access
        return head :unauthorized
      end

      def verify_user_access
        head :unauthorized unless user_has_valid_access?

        set_current_user_cookies
      end

      def user_has_valid_access?
        check_user ||
          Rails.env.development? ||
          safe_formats.any? {|f| request.format.__send__(f) }
      end

      def safe_formats
        [
          :html?,
          :css?,
          :js?,
        ]
      end

      def decrypt_certificate(cert)
        cert.clean_certificate
      rescue
      end

      def get_passport_link(user)
        user.passport && url_with_auth(get_file_admin_user_passport_path(user))
      end

      def url_with_auth(path)
        "http#{
          Rails.env.development? ? '' : "s"
        }://authorize.#{
          local_domain
        }#{
          path
        }"
      end

      def local_port
        request.port || ENV['LOCAL_PORT'] || '3100'
      end

      def local_domain
        Rails.env.development? ? "lvh.me:#{local_port}" : "downundersports.com"
      end

      def lookup_user
        @found_user = User.get(params[:user_id].presence || params[:id])

        @found_user = authorize(@found_user) unless request.format.html?
      end

      def not_authorized_error
        self.class.not_authorized_error
      end

      def not_defined_error
        self.class.not_defined_error
      end

      def not_authorized(errors = nil, status = 401)
        errors = case errors
        when not_authorized_error, nil
          [ 'You are not authorized to perform the requested action' ]
        when String
          [
            errors
          ]
        else
          errors
        end

        return render json: {
          errors: errors
        }, status: status
      end

      def record_not_found(errors = nil, status = 500)
        return not_authorized(errors, status)
      end

      def json_request?
        request.format.json?
      end

      def render_success(record_id = nil)
        render json: {
          id: record_id,
          success: true
        }, status: 200
      end

      def run_an_api_action
        successful, errors, record = nil

        begin
          record = yield
          successful = true
        rescue
          successful = false
          errors = $!.message.split("\n")
          puts $!.message
          puts $!.backtrace
        end

        puts "RUN ACTION: #{record&.respond_to?(:id)}"

        record = nil unless record&.respond_to?(:id)

        return successful ? render_success(record&.id) : not_authorized(errors, 422)
      end

      def whitelisted_user_params
        params.require(:user).
          permit(
            :set_as_traveling,
            :title,
            :first,
            :middle,
            :last,
            :suffix,
            :keep_name,
            :gender,
            :email,
            :phone,
            :can_text,
            :state,
            :sport,
            :interest_id,
            :birth_date,
            :shirt_size,
            :stats,
            :athlete_sport_id,
            :athlete_grad,
            :stats_sport_id,
            :main_event,
            :main_event_best,
            :unlink_address,
            :print_first_names,
            :print_other_names,
            :school_id,
            :checked_background,
            :polo_size,
            :departing_date_override,
            :returning_date_override,
            travel_preparation_attributes: [
              :id,
              :early_payoff_deadline,
              :final_payment_deadline,
              :rollover_deadline,
              :two_thousand_deadline,
            ],
            address_attributes: [
              :id,
              :is_foreign,
              :street,
              :street_2,
              :street_3,
              :city,
              :state_id,
              :province,
              :zip,
              :country
            ],
            override_attributes: [
              :id,
              :payment_description
            ],
            athletes_sports_attributes: [
              :id,
              :sport_id,
              :rank,
              :main_event,
              :main_event_best,
              :stats,
              :height,
              :weight,
              :handicap,
              {positions_array: []},
              :_destroy
            ]
          )
      end
  end
end
