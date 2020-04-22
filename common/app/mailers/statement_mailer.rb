class StatementMailer < ImportantMailer
  def join
    send_stuff('Down Under Sports - Statement Info')
  end

  def status_update
    send_stuff('Monthly Account Update')
  end

  def departure_checklist
    m = send_stuff('Departure Checklist')
    m.after_send do
      message = "Sent Departure Checklist email"
      @user.contact_histories.create(
        category: :email,
        message: message,
        staff_id: auto_worker.category_id
      )
    end
  end

  def legal_docs
    m = send_stuff('Missing Legal Documents for :FULLNAME')
    m.after_send do
      message = "Sent Missing Legal Docs email"
      @user.contact_histories.create(
        category: :email,
        message: message,
        staff_id: auto_worker.category_id
      )
    end
  end

  def over_payment_request
    return false unless @request = User::RefundRequest.includes(:user).find(params[:id])

    mail to: %w[ karen@downundersports.com it@downundersports.com ], subject: "Over-Payment Request submitted for #{@request.user.dus_id}"
  end

  private
    def send_stuff(subj)
      @user = User.get(params[:user_id])
      email = @user.athlete_and_parent_emails.presence || 'mail@downundersports.com'

      mail to: email, subject: subj.sub(':FULLNAME', @user.full_name)
    end
end
