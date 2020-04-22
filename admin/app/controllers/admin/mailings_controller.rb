# encoding: utf-8
# frozen_string_literal: true

module Admin
  class MailingsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [:show, :categories]

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      mailings = authorize Mailing.order(:created_at).where(user: @found_user)

      if Boolean.parse(params[:force]) || stale?(mailings)
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y)

          deflator.stream false, :version, last_update
          deflator.stream true, :is_admin, current_user&.staff&.check(:admin)
          deflator.stream true, :mailings, '['

          i = 0
          mailings.map do |m|
            deflator.stream (i += 1) > 1, nil, {
              id: m.id,
              user_id: m.user_id,
              category: m.category&.titleize,
              address: Address.new(m.address).inline,
              failed: m.failed,
              is_home: m.is_home,
              sent: m.sent.presence&.strftime('%a %b %d'),
              form_attributes: m.as_json
            }
          end

          deflator.stream false, nil, ']'

          deflator.close
        end
      end
    end

    def categories
      return render json: { categories: (Mailing.uniq_column_values(:category).map(&:category).map {|cat| cat =~ /^invite/ ? "invite" : cat}).uniq.sort }
    end

    def show
      respond_to do |format|
        format.html { return redirect_to admin_mailing_path(params[:id], format: :csv) }
        format.csv do
          @mailings = authorize Mailing.where('category ilike ?', "%#{params[:id].to_s.underscore}%")

          render csv: "show", filename: "mailings-#{params[:id]}", with_time: true
        end
      end
    end

    def create
      successful, errors, mailing = nil

      begin
        mailing = @found_user.mailings.create!(whitelisted_mailing_params)
        successful = true
      rescue
        successful = false
        puts errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success(mailing.id) : not_authorized(errors, 422)
    end

    def update
      @mailing = @found_user.mailings.find_by(id: params[:id])
      respond_to do |format|
        format.json do
          begin
            if @mailing && Boolean.parse(params[:switch_to_home])
              @mailing.switch_to_home_if_available!
            else
              raise "Not Allowed" unless current_user&.staff&.check(:admin)
              if Boolean.parse(params[:DELETE_MAILING])
                @mailing.destroy!
              else
                @mailing.update!(whitelisted_mailing_params)
              end
            end
            return render_success(@mailing.id)
          rescue
            return not_authorized($!.message, 422)
          end
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def last_update
        begin
          return nil unless @found_user.mailings.count > 0
          @found_user.mailings.
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end

      def whitelisted_mailing_params
        whitelisted = params.require(:mailing).permit(
          :id,
          :category,
          :sent,
          :explicit,
          :is_home,
          :is_foreign,
          :street,
          :street_2,
          :street_3,
          :city,
          :state,
          :zip,
          :country,
        )
        if whitelisted[:category].present? && (whitelisted[:category] =~ /^invite/)
          raise "Cannot Send Invite to Non-Athletes" unless @found_user.is_athlete?
          whitelisted[:is_home] = @mailing.is_home if @mailing && whitelisted[:is_home].to_s.blank?
          whitelisted[:is_home] = Boolean.parse(whitelisted[:is_home])
          whitelisted[:category] = "invite_#{whitelisted[:is_home] ? "home" : "school"}"
          address =
            (
              whitelisted[:is_home] ?
                (@found_user.main_address || @found_user.athlete&.school&.address) :
                @found_user.athlete&.school&.address
            ) || Address.new

          whitelisted.merge!(address.to_shipping)
        end
        whitelisted
      end
  end
end
