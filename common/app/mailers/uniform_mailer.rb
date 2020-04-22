class UniformMailer < ImportantMailer
  # default use_account: :travel

  def received(uniform_id, resending = false)
    @order = User::UniformOrder.find_or_retry_by(id: uniform_id)
    puts @order
    if @order

      m = mail  to:       @order.user.athlete_and_parent_emails,
                subject:  "We have received your uniform order for #{@order.sport.full}",
                bcc:      Boolean.parse(resending) ? 'it@downundersports.com' : nil

      m && m.after_send do
        message = "Sent Uniform Order Received Email for #{@order.sport.abbr_gender} \##{@order.id}"

        @order.user.contact_histories.create(
          category: :email,
          message: message,
          staff_id: auto_worker.category_id
        )
      end
    end
  end

  def place(uniform_id)
    @uniform_order = User::UniformOrder.find_or_retry_by(id: uniform_id)
    # production_email('mekenzie@welogostuff.com')
    if @uniform_order
      m = mail  to:      'sara@downundersports.com',
                subject: 'Down Under Sports Uniform Order',
                bcc:     'it@downundersports.com'
    end
  end

  def needed(user_id, sport_id = nil)
    @user = User.find_or_retry_by(id: user_id)
    @sport = Sport.find_by(id: sport_id) || @user.team.sport

    if @user && (@user.uniform_orders.count == 0)
      mail  to: @user.athlete_and_parent_emails,
            subject: 'Down Under Sports Uniform Order'
    end
  end
end
