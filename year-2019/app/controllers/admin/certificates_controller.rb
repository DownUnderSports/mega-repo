# encoding: utf-8
# frozen_string_literal: true
module Admin
  class CertificatesController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout false

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      @renderable = {}
      if is_proxy?
        @renderable[:success] = true
      else
        header_hash.each do |k, v|
          begin
            next if k.to_s =~ /rack|action_|puma/
            j = v.to_json
            @renderable[k] = v
          rescue Exception
            @renderable[k] = "#{$!.message}: #{k}"
          end
        end
      end
      @renderable[:CLEAN_CERT] = header_hash[certificate_header]&.clean_certificate
    end

    def create
      if (@pwd = User.where(id: auto_worker&.id).where(%q(password = crypt(?, password)), params[:cert_password])) &&
          (@stu = User.find_by(category_type: :staffs, id: params[:user_id])) &&
          @cert = header_hash[certificate_header]&.clean_certificate

        @stu.update!(new_certificate: @cert, new_certificate_confirmation: @cert) if @cert.present?
        redirect_to admin_users_path
      else
        raise "Not Found"
      end
    rescue
      redirect_to "#{admin_certificates_path}?pwd=#{!!@pwd}&stu=#{!!@stu}&cert=#{@cert.present?}&msg=#{$!.message}"
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def ensure_proxy
        true
      end

      def is_proxy?
        !!(
          (header_hash[:HTTP_HOST] =~ /(\.|^)downundersports\.com$/i) &&
          (header_hash[:HTTP_X_FORWARDED_BY] == '10.0.0.10:443') &&
          (header_hash[:HTTP_X_FORWARDED_FOR] =~ /(204\.132\.140\.194|74\.92\.245\.66)$/)
        )
      end
  end
end
