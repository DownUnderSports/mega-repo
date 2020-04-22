# Preview all emails at http://localhost:3000/rails/mailers/infokit
class InfokitPreview < ActionMailer::Preview
  def send_infokit
    InfokitMailer.send_infokit(User.athletes.first.category_id, 'sampsonsprojects@gmail.com', User.first.dus_id)
  end
end
