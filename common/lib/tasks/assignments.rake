# encoding: utf-8
# frozen_string_literal: true

namespace :assignments do
  desc 'Delete Visited Assignments for the day'
  task reset_visits: :environment do
    Staff::Assignment.where(id: Staff::Assignment::Visit.select(:assignment_id)).update_all(updated_at: Time.zone.now)
    Staff::Assignment::Visit.delete_all
    Staff::Assignment::Views::Respond.reload
  end

  task send_summary: :environment do
    StaffMailer.assignment_summary.deliver_now
  end
end
