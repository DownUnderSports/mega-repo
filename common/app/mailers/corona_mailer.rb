class CoronaMailer < ImportantMailer
  # default use_account: :travel

  # def cancel_selected
  #   send_selection_email("Preselected Account Option")
  # end
  #
  # def cancel_unselected
  #   send_selection_email("Unselected Account Option")
  # end
  #
  # def cancel_reminder
  #   send_selection_email("Account Option Selection Reminder")
  # end

  def cancel_info
    send_email_with_history "Cancel Information (Account Options)"
  end

  def fundraising_info
    send_email_with_history "Corona Fundraising Information (T-Shirts)",
                            "Fundraising Status"
  end

  def september_cancel_update
    send_email_with_history "September Update (Cancels)",
                            "September Update"
  end

  private
    def send_email_with_history(message, subject = "Account Options")
      @user = User[params[:user_id]]

      email =
        (
          case params[:email]
          when String
            params[:email].presence&.split(";")
          when Array
            params[:email].map(&:to_s)
          end
        )&.map(&:strip)&.select(&:present?)&.presence ||
        @user&.athlete_and_parent_emails.presence

      m = mail skip_filter: true, to: email, subject: subject, include_gayle: true

      if m && email.present? && @user
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
