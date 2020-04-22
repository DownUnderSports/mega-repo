class EventRegistrationMailer < ImportantMailer
  def athlete(registration_id, resending = false)
    @event_reg = User::EventRegistration.find_or_retry_by(id: registration_id)
    if @event_reg
      if @event_reg.has_event?('hammer') || @event_reg.has_event?('pole vault')
        attachments["certificate-of-competency.pdf"] = {
          mime_type: 'application/pdf',
          content: File.read(Rails.root.join('public', 'certificate-of-competency.pdf'))
        }
      end
      options = {
        to: production_email(@event_reg.user.athlete_and_parent_emails),
        subject: 'We have received your event registration'
      }
      options[:bcc] = it_email unless Boolean.parse(resending)
      mail options
    end
  end

  def sports_credentials(registration_id, resending = false)
    @event_reg = User::EventRegistration.find_or_retry_by(id: registration_id)
    if @event_reg
      attachments["event_registration-#{@event_reg.user.full_name}.csv"] = render template: 'shared/track_events/event_table.csv', layout: false
      attachments["event_registration-#{@event_reg.user.full_name}.json"] = render template: 'shared/track_events/event_table.json', layout: false
      options = {
        to: production_email([]),
        subject: 'Track Event Registration'
      }
      options[:bcc] = it_email unless Boolean.parse(resending)
      mail options
    end
  end

  def competent(registration_id)
    @event_reg = User::EventRegistration.find_or_retry_by(id: registration_id)
    if @event_reg
      attachments["certificate-of-competency.pdf"] = {
        mime_type: 'application/pdf',
        content: File.read(Rails.root.join('public', 'certificate-of-competency.pdf'))
      }

      mail to: production_email(@event_reg.user.athlete_and_parent_emails), subject: 'Track Event Certificate of Competency'
    end
  end

  def needed(user_id)
    @user = User.find_or_retry_by(id: user_id)
    if @user && @user.is_athlete? && (@user.event_registrations.count == 0)
      mail to: production_email(@user.athlete_and_parent_emails.presence || 'it@downundersports.com'), subject: 'We need your Event Registration'
    else
      mail to: production_email('it@downundersports.com'), subject: "Unnecessary Event Reg Email attempted - #{@user.url}"
    end
  end

  def not_needed(user_id)
    @user = User.find_or_retry_by(id: user_id)
    mail to: production_email(@user.athlete_and_parent_emails.presence || 'it@downundersports.com'), subject: 'We actually do not need your Event Registration'
  end
end
