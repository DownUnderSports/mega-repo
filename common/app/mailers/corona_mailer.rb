class CoronaMailer < ImportantMailer
  # default use_account: :travel

  def cancel_selected
    send_selection_email("Preselected Account Option")
  end

  def cancel_unselected
    send_selection_email("Unselected Account Option")
  end

  private
    def send_selection_email(message)
      @user = User[params[:user_id]]

      email =
        params[:email].presence ||
        @user.athlete_and_parent_emails.presence

      m = mail skip_filter: true, to: email, subject: "Account Options"

      if m && email.present?
        m.after_send do
          @user.contact_histories.create(
            category: :email,
            message: "#{message} Email Sent To: #{email&.join(", ")}",
            staff_id: params[:staff_id].presence || auto_worker.category_id
          )
        end
      end

      m
    end
end
