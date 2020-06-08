# Preview all emails at http://localhost:3000/rails/mailers/user
class StaffPreview < ActionMailer::Preview
  def assignment_summary
    StaffMailer.assignment_summary
  end
end
