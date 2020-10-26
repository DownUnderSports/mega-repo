# Preview all emails at http://localhost:3000/rails/mailers/travel
class TravelPreview < ActionMailer::Preview
  def may_newsletter
    TravelMailer.with(email: "mail@downundersports.com").may_newsletter
  end

  def june_newsletter
    TravelMailer.with(params).june_newsletter
  end

  def july_newsletter
    TravelMailer.with(params).july_newsletter
  end

  def august_newsletter
    TravelMailer.with(params).august_newsletter
  end

  def august_deferral_newsletter
    TravelMailer.with(params).august_deferral_newsletter
  end

  def august_cancel_newsletter
    TravelMailer.with(params).august_cancel_newsletter
  end

  def april_deadline_approaching
    TravelMailer.with(params).april_deadline_approaching
  end

  def cancellation_received
    TravelMailer.with(params).cancellation_received
  end

  def cancellation_update
    TravelMailer.with(params).cancellation_update
  end

  def cancellation_update_two
    TravelMailer.with(email: "sampson@downundersports.com").cancellation_update_two
  end

  def transfer_confirmed
    TravelMailer.with(params).transfer_confirmed
  end

  def on_the_fence
    TravelMailer.with(params).on_the_fence
  end

  def coronavirus_update
    TravelMailer.with(params).coronavirus_update
  end

  def coronavirus_update_one
    TravelMailer.with(params).coronavirus_update_one
  end

  def coronavirus_update_two
    TravelMailer.with(params).coronavirus_update_two
  end

  def coronavirus_update_three
    TravelMailer.with(params).coronavirus_update_three
  end

  def coronavirus_update_four
    TravelMailer.with(params).coronavirus_update_four
  end

  def refund_apology
    TravelMailer.with(params).refund_apology
  end

  def refund_amount
    TravelMailer.with(params).refund_amount
  end

  def duffel_bag_sent
    TravelMailer.with(params).duffel_bag_sent
  end

  def email_blast
    TravelMailer.with(params).email_blast
  end

  def event_results
    TravelMailer.with(params).event_results
  end

  def survey
    TravelMailer.with(params).survey
  end

  def survey_try_2
    TravelMailer.with(params).survey_try_2
  end

  def travel_packet
    TravelMailer.with(params).travel_packet
  end

end
