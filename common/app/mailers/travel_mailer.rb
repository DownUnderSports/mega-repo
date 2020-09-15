class TravelMailer < ImportantMailer
  # default use_account: :travel

  def may_newsletter
    attachments["may-newsletter.pdf"] = {
      mime_type: 'application/pdf',
      content: File.read(get_full_path_to_asset('may_2020_newsletter.pdf'))
    }

    mail skip_filter: true, to: params[:email].presence, subject: "May Newsletter"
  end

  def june_newsletter
    attachments["june-newsletter.pdf"] = {
      mime_type: 'application/pdf',
      content: File.read(get_full_path_to_asset('june_2020_newsletter.pdf'))
    }

    mail skip_filter: true, to: params[:email].presence, subject: "June Newsletter"
  end

  def july_newsletter
    attachments["july-newsletter.pdf"] = {
      mime_type: 'application/pdf',
      content: File.read(get_full_path_to_asset('july_2020_newsletter.pdf'))
    }

    mail to: params[:email].presence, subject: "July Newsletter"
  end

  def august_newsletter
    attachments["august-newsletter.pdf"] = {
      mime_type: 'application/pdf',
      content: File.read(get_full_path_to_asset('august_2020_newsletter.pdf'))
    }

    mail to: params[:email].presence, subject: "August Newsletter"
  end

  def august_deferral_newsletter
    # attachments["august-newsletter.pdf"] = {
    #   mime_type: 'application/pdf',
    #   content: File.read(get_full_path_to_asset('august_2020_newsletter.pdf'))
    # }

    mail to: params[:email].presence, subject: "August Update"
  end

  def august_cancel_newsletter
    # attachments["august-newsletter.pdf"] = {
    #   mime_type: 'application/pdf',
    #   content: File.read(get_full_path_to_asset('august_2020_newsletter.pdf'))
    # }

    mail to: params[:email].presence, subject: params[:subject].present? ? "August Update (#{params[:subject]})" : "August Update", include_gayle: true
  end

  def april_deadline_approaching
    @user = User.get(params[:user_id])
    email = @user.athlete_and_parent_emails.presence || [ 'mail@downundersports.com' ]
    m = mail skip_filter: true, to: email, subject: 'Down Under Sports - Travel Preparations'

    if m
      m.after_send do
        @user.contact_histories.create(message: "Sent 4/20 Deadlines Email to #{email.join(';')}", category: :email, staff_id: auto_worker.category_id)
      end
    end

    m
  end

  def cancellation_received
    @user = User[params[:id]]
    return false unless @user.traveler
    email = params[:email].presence || @user.athlete_and_parent_emails
    mail skip_filter: true, to: email, subject: 'Cancellation Confirmation'
  end

  def cancellation_update
    @user = User[params[:id]]
    return false unless @user.traveler
    email = params[:email].presence || @user.athlete_and_parent_emails
    mail skip_filter: true, to: email, subject: 'A Message from Down Under Sports'
  end

  def transfer_confirmed
    @user = User[params[:id]]
    return false unless @user.traveler
    email = params[:email].presence || @user.athlete_and_parent_emails
    mail skip_filter: true, to: email, subject: 'Transfer Confirmation'
  end

  def on_the_fence
    mail skip_filter: true, to: params[:email].presence, subject: "Would you like to travel in 2021?"
  end

  def coronavirus_update
    @sport =
      (Sport[params[:sport]] || Sport.find_by(abbr: params[:sport].abbr_format))
    raise "Invalid Sport" unless @sport && @sport.rep
    mail skip_filter: true, to: params[:email].presence, subject: "#{@sport.full} Update"
  end

  def coronavirus_update_one
    mail skip_filter: true, bcc: params[:emails].presence, subject: 'Travel Update'
  end

  def coronavirus_update_two
    mail skip_filter: true, bcc: params[:emails].presence, subject: 'Travel Update'
  end

  def coronavirus_update_three
    return coronavirus_update
  end

  def coronavirus_update_four
    mail skip_filter: true, to: params[:email].presence, subject: "We Appreciate Your Understanding"
  end

  def refund_apology
    email = params[:email].presence

    return false unless email.present?

    mail skip_filter: true, to: email, subject: "Refund Information", include_gayle: true
  end

  def refund_amount
    @user = User[params[:user_id]]
    # email = params[:email].presence || @user&.athlete_and_parent_emails
    # email = [email].flatten.select(&:present?).presence

    # unless @user.present? &&
    #         email.present? &&
    #         (@user.transfer_expectation&.fully_canceled? || (@user == test_user))
    @user&.contact_histories&.create(
      category: :email,
      message: "Failed to Send Refund Amount Email: Disabled until Further Notice",
      # message: "Failed to Send Refund Amount Email: #{email ? 'No Email Found' : 'User Not Fully Canceled'}",
      staff_id: params[:staff_id].presence || auto_worker.category_id
    )

    return false
    # end

    # @has_insurance =
    #   Boolean.parse(params[:force_insurance]) ||
    #   !!@user.traveler.insurance_debit
    #
    # @refundable_amount =
    #   StoreAsInt.money(
    #     params[:refundable_amount].presence ||
    #     @user.traveler.refundable_amount
    #   )
    #
    # m = mail skip_filter: true, to: email, subject: "Refund Summary"
    #
    # if m
    #   m.after_send do
    #     @user.contact_histories.create(
    #       category: :email,
    #       message: "Sent Refund Amount Email (#{@refundable_amount.to_s(true)}) to: #{email.join("; ")}",
    #       staff_id: params[:staff_id].presence || auto_worker.category_id
    #     )
    #   end
    # end
    #
    # m
  end

  def duffel_bag_sent
    @user = User[params[:user_id]]

    email = @user.athlete_and_parent_emails.presence

    m = mail skip_filter: true, to: email, subject: "Your Ogio Duffel Bag has Shipped!"

    if m && email.present?
      m.after_send do
        @user.contact_histories.create(
          category: :email,
          message: "Sent Duffel Bag Shipped Email to: #{email.first}",
          staff_id: auto_worker.category_id
        )
      end
    end

    m
  end

  def email_blast
    @subject = params[:subject]
    @banner = params[:banner].presence
    @email_body = params[:body]

    mail bcc: filter_emails(params[:emails].presence), subject: @subject
  end

  def event_results
    @sport = Sport[params[:sport]]
    @subject = params[:subject]
    @description = params[:description]
    mail bcc: filter_emails(params[:emails].presence), subject: @subject
  end

  def survey
    mail bcc: filter_emails(params[:emails].presence), subject: "Down Under Sports - Tell us how we did!"
  end

  def survey_try_2
    mail bcc: filter_emails(params[:emails].presence), subject: "Down Under Sports - Help us improve!"
  end

  def travel_packet
    @user = User[params[:user_id]]

    email = params[:email].presence || @user.athlete_and_parent_emails

    m = mail skip_filter: true, to: email, subject: "Down Under Sports Travel Details"

    if m
      m.after_send do
        @user.contact_histories.create(
          category: :email,
          message: "Sent Final Packet Email to: #{email.first}",
          staff_id: auto_worker.category_id
        ) if email.present?
      end
    end

    m
  end
end
