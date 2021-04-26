# encoding: utf-8
# frozen_string_literal: true

module API
  class ApplicationController < ActionController::API
    # == Modules ============================================================
    include ActionController::Cookies
    include ActionController::HttpAuthentication::Token::ControllerMethods
    include BetterRecord::Authenticatable
    include Pundit
    include Fetchable

    # == Class Methods ======================================================
    def self.not_authorized_error
      Pundit::NotAuthorizedError
    end

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def version
      render plain: DownUnderSports::VERSION
    end

    # == Cleanup ============================================================
    rescue_from not_authorized_error, with: :not_authorized

    private
      def cookie_domain
        :all
      end

      def set_current_user_cookies(user_to_set = nil)
        if user_to_set ||= BetterRecord::Current.user
          result = (
            cookies.encrypted[:current_user_id] = {
              value: user_to_set.id,
              expires: Time.now + 24.hours,
              secure: false,
              domain: cookie_domain,
              tld_length: 2
            }
          )

          cookies[:plain_id] = {
            value: user_to_set.id,
            expires: Time.now + 24.hours,
            secure: false,
            domain: cookie_domain,
            tld_length: 2
          }

          if Rails.env.production?
            cookies.encrypted[:current_user_id_legacy] = {
              value: user_to_set.id,
              expires: Time.now + 24.hours,
              secure: false,
              domain: cookie_domain,
              tld_length: 2
            }

            cookies[:plain_id_legacy] = {
              value: user_to_set.id,
              expires: Time.now + 24.hours,
              secure: false,
              domain: cookie_domain,
              tld_length: 2
            }
          end

          result
        else
          cookies.delete :current_user_id, domain: cookie_domain, tld_length: 2
          cookies.delete :current_user_id_legacy, domain: cookie_domain, tld_length: 2
          cookies.delete :plain_id, domain: cookie_domain, tld_length: 2
          cookies.delete :plain_id_legacy, domain: cookie_domain, tld_length: 2
          nil
        end
      end

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

      def current_user_hash(minimal = false)
        u = current_user || check_user || User.new
        {
          id: u.id,
          staff: u.is_staff? ? 1 : nil,
        }.merge(
          minimal ?
            {} :
            {
              permissions: (
                u.is_staff? ?
                u.staff.attributes.symbolize_keys :
                {
                  user_ids: [u.id, *u.related_users.map(&:id)],
                  dus_ids: [u.dus_id, *u.related_users.map(&:dus_id)]
                }
              ),
              attributes: {
                id: u.id,
                avatar: (u.avatar.attached? ? url_for(u.avatar.variant(resize: '500x500>', auto_orient: true)) : '/mstile-310x310.png'),
                dus_id: u.dus_id,
                category: u.category_title,
                email: u.email,
                phone: u.phone,
                extension: u.extension,
                title: u.title,
                first: u.first,
                middle: u.middle,
                last: u.last,
                suffix: u.suffix,
                name: u.full_name,
                print_names: u.print_names,
                print_first_names: u.print_first_names,
                print_other_names: u.print_other_names,
                nick_name: u.nick_name,
                gender: u.gender,
                shirt_size: u.shirt_size,
              }
            }
        )
      end

      def not_authorized_error
        self.class.not_authorized_error
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
        }, status: 403
      end

      def decrypt_token(token, options = nil, **other)
        value, gpg_status = token.presence && decrypt_gpg_base64(token).presence
        puts gpg_status if Rails.env.development?
        value
      rescue Exception
      end

      def encrypt_token
        current_token.presence && encrypt_and_encode_str(current_token)
      rescue Exception
        nil
      end

      def requesting_device_id
        @requesting_device_id ||= "development"
      end
  end
end
