# Preview all emails at http://localhost:3000/rails/mailers/meeting/reminder
class Meeting < ApplicationRecord
  class ReminderPreview < ActionMailer::Preview
    def upcoming
      get_mailer.upcoming
    end

    def registered
      get_mailer.registered
    end

    private
      def get_mailer
        Meeting::ReminderMailer.with(meeting_id: Meeting.last.id)
      end
  end
end
