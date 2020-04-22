# encoding: utf-8
# frozen_string_literal: true

module Admin
  class SampsonController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'standalone'

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      redirect_to '/admin' unless authorize(current_user, :admin?) && current_user.first === 'Sampson'
    end

    def create
      wl_params = whitelisted_params.to_h.symbolize_keys


      @sport = params[:sport]
      sport = Sport[@sport]
      sport = sport ? Sport.where(id: sport.id) : Sport.where("abbr ilike ?", "%#{@sport}")

      if params[:confirmed] === "confirmed"
        emails = []
        Traveler.
          active.
          joins(:team).
          where(teams: { sport: sport.size ? sport : Sport.all }).split_batches_values do |t|
            emails << t.user.athlete_and_parent_emails unless t.user.is_staff?
          end



        emails = ['sampson@DownUnderSports.com'] if Rails.env.development?

        [*emails.flatten.uniq.sort, 'ISSI-USA@downundersports.com'].in_groups_of(50, false) do |ems|
          TravelMailer.with(emails: ems, **wl_params).email_blast.deliver_later
        end
      else
        @confirmation = true
      end

      @email_body = wl_params[:body]
      @banner = wl_params[:banner]
      @subject = wl_params[:subject]

      render file: 'travel_mailer/email_blast.html.inky', layout: 'mailer', formats: [:inky]
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      if Rails.env.development?
      end

      def whitelisted_params
        params.permit(
          :subject,
          :body,
          :banner,
        )
      end
  end
end
