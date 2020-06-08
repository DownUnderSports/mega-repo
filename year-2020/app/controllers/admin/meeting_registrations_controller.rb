# encoding: utf-8
# frozen_string_literal: true

module Admin
  class MeetingRegistrationsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          registrations = @found_user.
            meeting_registrations.
            joins(:meeting).
            references(:meeting).
            select(:id, :meeting_id, :user_id, 'meetings.start_time', 'meetings.category', :attended, :duration).
            order('meetings.category', 'meetings.start_time')

          if stale? registrations
            return render json: {
              registrations: (
                registrations.map do |registration|
                  start_time = Time.zone.parse(registration.start_time.to_datetime.to_s)
                  {
                    id: registration.id,
                    meeting_id: registration.meeting_id,
                    user_id: registration.user_id,
                    date: start_time.to_date.to_s,
                    time: start_time.strftime("%r"),
                    category: Meeting::Category.titleize(registration.category),
                    duration: registration.duration,
                    attended: !!registration.attended
                  }
                end
              ),
              version: last_update
            }
          end
        end
      end
    end

    def update
      save_registration @found_user.meeting_registrations.find_by(id: params[:id])
    end

    def create
      save_registration @found_user.meeting_registrations, 'create!'.to_sym
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def last_update
        begin
          return nil unless @found_user.meeting_registrations.count > 0

          @found_user.meeting_registrations.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first.utc.iso8601
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

      def save_registration(registration, method = 'update!'.to_sym)
        successful, errors, rel = nil

        begin
          if params[:id].present? && whitelisted_registration_params[:meeting_id].blank?
            Meeting::Registration.
            where(
              meeting_id: registration.meeting_id,
              user_id: [ @found_user.id, *@found_user.relations.map(&:related_user_id) ]
            ).each {|reg| reg.destroy! }
          else
            if params[:registration][:duration].blank?
              params[:registration][:attended] = false
              params[:registration][:duration] = '00:00:00'
            end
            if method.to_s =~ /create/
              registration = registration.__send__(method, whitelisted_registration_params)
              @found_user.related_users.each do |u|
                registration = registration.dup
                registration.user = u
                registration.save!
              end
            else
              Meeting::Registration.
              where(
                meeting_id: registration.meeting_id,
                user_id: [ @found_user.id, *@found_user.relations.map(&:related_user_id) ]
              ).
              each do |reg|
                reg.__send__(method, whitelisted_registration_params)
              end
            end
          end

          successful = true
        rescue
          successful = false
          puts errors = $!.message
          puts $!.backtrace
        end

        return successful ? render_success : not_authorized(errors, 422)
      end

      def whitelisted_registration_params
        params.require(:registration).permit(:id, :meeting_id, :attended, :duration)
      end

  end
end
