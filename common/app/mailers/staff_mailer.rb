class StaffMailer < ImportantMailer
  def respond_after_uncontactable
    return false unless @user = User.get(params[:user_id])

    @interest = Interest.find_by(id: params[:interest_id]) ||
      (
        @user.interest.contactable? ?
          Interest[
            @user.logged_actions.
              order(:event_id).
              where("changed_fields ? 'interest_id'").
              where.not("changed_fields -> 'interest_id' = ANY(ARRAY[?])", Interest.contactable_ids.map(&:to_s)).
              last&.changed_fields&.[]('interest_id') ||
            @user.logged_actions.
              order(:event_id).
              where("row_data -> 'interest_id' = ANY(ARRAY[?])", Interest.contactable_ids.map(&:to_s)).
              take&.row_data&.[]('interest_id')&.to_i ||
            @user.interest
          ] :
          @user.interest
      )

    @category = params[:category].presence || 'Not Provided'

    mail to: 'mail@downundersports.com', subject: "New Activity from Uncontactable User - #{@user.dus_id}"
  end

  def chat_waiting
    @room = ChatRoom.find_by(id: params[:uuid])
    return false if !@room || @room.is_closed || @room.get_count("staff")&.>(0) || !(@room.get_count("clients")&.>(0))
    mail to: 'mail@downundersports.com', subject: "Chat Room Staff Needed"
  end

  def assignment_summary
    Staff::Assignment::Views::Respond.live_reload

    mail to: 'ISSI-USA@downundersports.com', subject: "Call Assignments @ #{Time.zone.now.strftime("%m/%d/%Y %H:%M")}"
  end

  def assignment_completed
    return false unless @assignment = Staff::Assignment.get(params[:id])

    mail to: 'management@downundersports.com', subject: "Assignment Marked Completed - #{@assignment.user.dus_id}"
  end

  def create_sponsor_photo
    return false unless @user = User.get(params[:user_id])

    mail to: 'it@downundersports.com', subject: "Sponsor Photo Submitted - #{@user.dus_id}"
  end

  def destroy_sponsor_photo
    return false unless @user = User.get(params[:user_id])

    mail to: 'it@downundersports.com', subject: "Sponsor Photo Removed - #{@user.dus_id}"
  end

  def founders_day
    return false unless @user = User.get(params[:id])

    mail to: 'it@downundersports.com', subject: "Founders Day Payment - #{@user.dus_id}"
  end

  def mail(**params)
    super(**params) do |format|
      format.html(content_transfer_encoding: 'quoted-printable')
    end
  end
end
