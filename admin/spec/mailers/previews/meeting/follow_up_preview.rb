# Preview all emails at http://localhost:3000/rails/mailers/meeting/follow_up
class Meeting < ApplicationRecord
  class FollowUpPreview < ActionMailer::Preview
    def thank_you_for_attending
      get_mailer.thank_you_for_attending
    end

    def sorry_we_missed_you
      get_mailer.sorry_we_missed_you
    end

    private
      def get_mailer
        Meeting::FollowUpMailer.with(meeting_id: Meeting.last.id, staff_user_id: auto_worker.id)
      end
  end
end
