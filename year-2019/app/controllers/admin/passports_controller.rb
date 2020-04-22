# encoding: utf-8
# frozen_string_literal: true

module Admin
  class PassportsController < Admin::ApplicationController
    # == Modules ============================================================
    include Passportable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    after_action :allow_iframe, only: :get_file_value

    # == Actions ============================================================
    def show
      u = authorize User.get(params[:user_id])
      raise "User Not Found" unless u
      return render json: (u.passport || {}).
        as_json.
        merge(
          has_questions_answered: !!(u.passport&.has_questions_answered?),
          needs_image: !(u.passport&.image&.attached?),
          link: get_passport_link(u),
          can_delete: current_user&.staff&.check(:admin)
        ).null_to_str
    end

    def update
      return render json: { errors: [ "CANNOT MODIFY USERS IN PREVIOUS YEARS" ] }, status: 422
    end

    def create
      return update
    end

    def destroy
      return update
    end

    def get_file
      user = authorize User.get(params[:user_id])
      raise "Could Not Find Image" unless user&.passport&.image&.attached?

      _, file_name, content_type = get_decrypted_content_type(user.passport.image)

      return render layout: 'layouts/internal.html.erb', locals: { user: user, file_name: file_name, content_type: content_type }
    end

    def get_file_value
      u = authorize User.get(params[:user_id])
      raise "Could Not Find Image" unless u&.passport&.image&.attached?

      if stale? u.passport.image.blob
        Tempfile.open(u.passport.image.filename.to_s, encoding: 'ascii-8bit') do |tempfile|
          tempfile << u.passport.image.download
          tempfile.rewind
          send_file(*get_options(tempfile, u.passport.image))
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def get_options(tempfile, file)
        should_decrypt, file_name, content_type = get_decrypted_content_type(file)
        [
          should_decrypt ? decrypt_gpg_file(tempfile.path, validate: false, tempfile: true) : tempfile,
          {
            filename: file_name,
            type: content_type,
            disposition: 'inline'
          }
        ]

      end

      def get_decrypted_content_type(file)
        ct = file.content_type.to_s
        if ct =~ /application\/pgp-encrypted\+/
          [
            true,
            file.filename.to_s.sub(/.gpg/, ''),
            ct.sub(/application\/pgp-encrypted\+/, '').sub(/----/, '/')
          ]
        else
          [
            false,
            file.filename.to_s,
            ct
          ]
        end
      end

      def allow_iframe
        response.headers.delete('X-Frame-Options')
        response.headers['X-Frame-Options'] = 'SAMEORIGIN'
      end
  end
end
