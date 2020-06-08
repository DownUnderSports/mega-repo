class CheckInChannel < ApplicationCable::Channel
  def subscribed
    stream_from "check_in"
  end
end
