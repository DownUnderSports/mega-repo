# encoding: utf-8
# frozen_string_literal: true

module API
  class EventRegistrationsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      u = User.find_by_dus_id_hash(params[:id])
      return head 404 unless u&.team && (u.gender != 'U')

      if stale? u
        return render json: {
          registered: !is_active_year? || u.has_event_registration?,
          sport: u.team.sport,
          state: u.team.state,
          name: u.print_names,
          dus_id: u.dus_id,
          user: {
            id: u.id,
            gender: u.gender,
            age_this_year: (Date.today.year - ((u.birth_date || 19.years.ago).year)).to_i
          }
        }, status: 200
      end
    end

    def update
      raise 'User Not Found' unless user = User.find_by_dus_id_hash(params[:id])
      raise 'User is not an Athlete' unless user.is_athlete?
      raise 'User is not traveling' unless user.traveler
      raise 'Event Registration Already Submitted' if user.event_registration

      user.create_event_registration!(**clear_empty_values(whitelisted_event_registration_params.to_h.deep_symbolize_keys), submitter_id: user.id)

      return render json: { message: 'ok' }, status: 200
    rescue
      return render json: {
        errors: [ $!.message ]
      }, status: 200
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def whitelisted_event_registration_params
        params.require(:event_registration).permit(*User::EventRegistration.event_params)
      end

      def clear_empty_values(h)
        bad_keys = []
        h.each do |k, v|
          h[k] = clear_empty_values(v) if v.is_a?(Hash)
          bad_keys << k unless v.present?
        end
        h.except(*bad_keys)
      end
  end
end
