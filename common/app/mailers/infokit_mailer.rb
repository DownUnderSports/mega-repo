# encoding: utf-8
# frozen_string_literal: true

class InfokitMailer < ApplicationMailer
  def coach_infokit(dus_id)
    @user = User.get(dus_id)

    m = mail to: @user.email, subject: "Program Information (Coaches Copy)"

    if m
      m.after_send do
        @user.contact_histories.create(message: 'Sent Infokit Email', category: :email, staff_id: auto_worker.category_id)
      end
    end

    m
  end

  def new_tryout
    @athlete = params[:athlete] || {}
    @nominator = params[:nominator] || {}
    # @guardian = params[:guardian] || {}
    # @address = Address.new(params[:address] || {})
    @submitted_by = params[:type]&.titleize
    @query = params[:query] || {}

    return false unless @athlete[:sport_abbr] && @athlete[:email]
    # return false unless @athlete[:sport_abbr] && @guardian[:email]

    mail to: 'gayle@downundersports.com', subject: "Open Tryout Submitted: #{@athlete[:sport_abbr]} #{@athlete[:school_state_abbr]}" do |format|
      format.html
    end
  end

  def delayed_infokit
    @user = User.get(params[:id])
    m = mail cc: params[:emails].presence, subject: 'Program Information Not Yet Available'
    if m
      m.after_send do
        @user.contact_histories.create(message: 'Sent Infokit Delayed Email', category: :email, staff_id: auto_worker.category_id)
      end
    end
    m
  end

  def send_infokit(athlete_id, email, dus_id, *args)
    @athlete = Athlete.find_or_retry_by(id: athlete_id).user
    @user = User.get(dus_id) || @athlete

    m = mail to: email, subject: 'Program Information'
    if m
      m.after_send do
        unless @user.contact_histories.where('message ilike ?', '%sent infokit email%').count > 0 || filter_emails(email).blank?
          InfokitMailer.
            send_followup_details(athlete_id, email, dus_id, false).
            deliver_later(wait_until: 3.days.from_now, queue: :mass_mailer)
        end
        @user.contact_histories.create(message: 'Sent Infokit Email', category: :email, staff_id: auto_worker.category_id)
      end
    end

    m
  end

  def send_followup_details(athlete_id, email, dus_id, force = false, *args)
    # if !force && (SentMail.where(%(created_at > ?), 24.hours.ago).count > 1000)
    #   InfokitMailer.
    #     send_followup_details(athlete_id, email, dus_id, force).
    #     deliver_later(wait_until: 1.hour.from_now, queue: :mass_mailer)
    #   return false
    # end

    email = filter_emails(email)

    return false unless email.present?

    @athlete = Athlete.find_or_retry_by(id: athlete_id).user
    @user = User.get(dus_id) || @athlete

    return false if !@user.interest.contactable ||
      !@athlete.interest.contactable || (
        !Boolean.parse(force) && (
          @athlete.traveler ||
            @user.video_views.find_by(watched: true) ||
            @user.contact_histories.find_by(message: 'Sent Kit Followup Email')
        )
      )

    m = mail to: email, subject: 'More Info'

    if m
      m.after_send do
        @user.contact_histories.create(message: 'Sent Kit Followup Email', category: :email, staff_id: auto_worker.category_id)
      end
    end

    m
  end

  def bad_name
    @dus_id, @db, @user, @guardian, @options, @domain = [
      params[:dus_id],
      params[:db] || {},
      params[:user] || {},
      params[:guardian] || {},
      params[:options] || {},
      Rails.env.development? ? 'http://lvh.me:3000' : "http://lvh.me"
    ]

    mail to: 'it@downundersports.com', subject: 'Bad Information Request' do |format|
      format.text
    end
  end
end
