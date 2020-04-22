# encoding: utf-8
# frozen_string_literal: true

require_dependency 'meeting'

class Meeting < ApplicationRecord
  class FollowUpEmailsJob < ApplicationJob
    queue_as :default

    def perform(**params)
      meeting = Meeting.find(params[:meeting_id])
      staff_id = auto_worker&.category_id

      [
        [ :thank_you_for_attending, meeting.attended_emails ],
        [ :sorry_we_missed_you, meeting.missed_emails ]
      ].each do |func, emails|
        message = "Sent #{func.to_s.titleize} email for meeting @ #{meeting.start_time.to_s(:long_ordinal)}"

        emails.each do |e, user_id|
          u = user_id.present? ? User.find_by(id: user_id) : User.find_by(email: e)
          unless !u || u.contact_histories.find_by(category: :email, message: message)
            Meeting::FollowUpMailer.with(**params.merge(email: e, user_id: user_id)).__send__(func).deliver_later
          end
        end

        Meeting::FollowUpMailer.with(**params.merge(email: nil, user_id: nil)).__send__(func).deliver_later
      end
    end
  end
end
