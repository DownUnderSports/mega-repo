class UserMailer < ImportantMailer
  def cancel
    @staff_user_id = params[:staff_user_id]
    @staff_user = User.find_by(id: @staff_user_id)
    send_stuff('Cancel Traveler', 'karen@downundersports.com')
  end

  private
    def send_stuff(subj, *other_emails)
      @user = User.get(params[:user_id])
      mail to: (['it@downundersports.com'] | (other_emails&.flatten || [])), skip_filter: true, subject: "#{subj} - #{@user.dus_id}"
    end
end
