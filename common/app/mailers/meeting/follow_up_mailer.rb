# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting'

class Meeting < ApplicationRecord
  class FollowUpMailer < Meeting::ApplicationMailer

    def thank_you_for_attending
      @meeting = Meeting.find(params[:meeting_id])
      @deposit_link = "https://downundersports.com/deposit"

      create_meeting_mail(
        :thank_you_for_attending.to_s.titleize,
        params[:email] || 'issi-usa@downundersports.com',
        params[:user_id].presence
      )
    end

    def sorry_we_missed_you
      @staff_user = User.get(params[:staff_user_id])
      @meeting = Meeting.find(params[:meeting_id])
      @deposit_link = "https://downundersports.com/deposit"

      create_meeting_mail(
        :sorry_we_missed_you.to_s.titleize,
        params[:email] || @staff_user.email,
        params[:user_id].presence
      )
    end

    def create_meeting_mail(subject, email, user_id = nil)
      u = user_id.present? ? User.find_by(id: user_id) : User.find_by(email: email)
      begin
        @deposit_link = "https://downundersports.com/deposit#{u ? "/#{u.related_athlete.dus_id}" : ''}"
      rescue
        @deposit_link = "https://downundersports.com/deposit"
      end

      m = mail(to: email, subject: subject)

      if u && m
        m.after_send do |result|
          message = "Sent #{subject} email for meeting @ #{@meeting.start_time.to_s(:long_ordinal)}"
          u.contact_histories.create(
            category: :email,
            message: message,
            staff_id: auto_worker.category_id
          )
        end
      end

      m
    end
  end
end
