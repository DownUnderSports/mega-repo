# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting'

class Meeting < ApplicationRecord
  class ReminderMailer < Meeting::ApplicationMailer

    def upcoming
      @meeting = Meeting.find(params[:meeting_id])

      create_meeting_mail(
        params[:email] || 'mail@downundersports.com'
      )
    end

    def registered
      @meeting = Meeting.find(params[:meeting_id])

      create_meeting_mail(
        (params[:email] || 'mail@downundersports.com'),
        'Registered for Meeting',
        'confirmation'
      )
    end

    private
      def create_meeting_mail(email, subject = 'Meeting Reminder', category = nil)
        u = params[:user_id] ? User.get(params[:user_id]) : User.find_by(email: params[:email])
        begin
          @deposit_link = "https://downundersports.com/deposit#{u ? "/#{u.related_athlete.dus_id}" : ''}"
        rescue
          @deposit_link = "https://downundersports.com/deposit"
        end

        m = mail(to: email, subject: subject)

        if m && u
          m.after_send do |result|
            message = params[:message] || "Sent #{category || subject.downcase} email for meeting @ #{@meeting.start_time.to_s(:long_ordinal)} to #{email}"
            u.contact_histories.create(
              category: :email,
              message: message,
              staff_id: auto_worker.category_id
            ) unless params[:history_id].presence && User::History.find_by(id: params[:history_id])
          end
        end

        m
      end
  end
end
