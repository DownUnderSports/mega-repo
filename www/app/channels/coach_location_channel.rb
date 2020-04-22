class CoachLocationChannel < ApplicationCable::Channel
  def subscribed
    stream_from current_airport
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def joined(*)
    ActionCable.server.broadcast(current_airport, { id: current_user&.dus_id, action: 'joined' })
  end

  def received(data)
    p data
  end

  private
    def current_airport
      "coach_location_#{params[:airport]}"
    end
end
