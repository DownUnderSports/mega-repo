class CoachLocationChannel < ApplicationCable::Channel
  def subscribed
    stream_from current_airport
  end

  def joined(*)
    ActionCable.server.broadcast(current_airport, { id: current_user&.dus_id, action: 'joined' })
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    stopped
  end

  def stopped(*)
    ActionCable.server.broadcast(current_airport, { id: current_user&.dus_id, action: 'stopped' })
  end

  def located(data)
    ActionCable.server.broadcast(current_airport, { id: current_user&.dus_id }.merge(data))
  end

  private
    def current_airport
      "coach_location_#{params[:airport]}"
    end
end
