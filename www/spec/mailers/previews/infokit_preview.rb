# Preview all emails at http://localhost:3000/rails/mailers/infokit
class InfokitPreview < ActionMailer::Preview
  def send_infokit
    InfokitMailer.send_infokit(User.where(category_type: 'athletes').first.category_id, 'it@downundersports.com', User.first.dus_id)
  end

  def send_followup_details
    InfokitMailer.send_followup_details(User.where(category_type: 'athletes').first.category_id, 'it@downundersports.com', User.first.dus_id, true)
  end
end
