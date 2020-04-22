class HolidayMailer < MarketingMailer
  def out_of_office
    mail bcc: params[:email].presence || 'mail@downundersports.com', subject: 'Happy Holidays!'
  end

  def black_friday_reminder
    mail bcc: params[:email].presence || 'mail@downundersports.com', subject: 'Discounts Expiring'
  end

  def halloween_offer
    mail bcc: params[:email].presence || 'mail@downundersports.com', subject: 'Happy Halloween!'
  end

  def xmas_responds_offer
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?

    mail to: emails, subject: 'Happy New Year!'
  end

  def new_year_traveler_offer
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?

    mail to: emails, subject: 'Happy Holidays!'
  end

  def new_year_offer_reminder
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?

    mail to: emails, subject: 'Still Time to Match!'
  end

  def new_year_new_us
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?

    mail to: emails, subject: 'New Year, New Us!'
  end

  def founders_day
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?
    return false if @user.traveler || (!@user.contactable && (@user.interest_id != Interest::NoRespond.id)) || @user.contact_histories.find_by(message: 'Sent Founders Day Email', staff_id: auto_worker.category_id)

    m = mail to: emails, subject: 'In Honor of Our Founders'

    if m
      m.after_send do |_|
        @user.contact_histories.create(
          message: 'Sent Founders Day Email',
          category: :email,
          staff_id: auto_worker.category_id
        )
      end
    end

    m
  end

  def founders_day_reminder
    return false unless @user = User.get(params[:dus_id])
    return false unless (emails = @user.athlete_and_parent_emails).present?
    return false if @user.traveler || (!@user.contactable && (@user.interest_id != Interest::NoRespond.id)) || @user.contact_histories.find_by(message: 'Sent Founders Day Reminder Email', staff_id: auto_worker.category_id)

    m = mail to: emails, subject: 'Today is Founders Day!'

    if m
      m.after_send do |_|
        @user.contact_histories.create(
          message: 'Sent Founders Day Reminder Email',
          category: :email,
          staff_id: auto_worker.category_id
        )
      end
    end

    m
  end
end
