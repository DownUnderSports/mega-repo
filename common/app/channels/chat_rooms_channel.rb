class ChatRoomsChannel < ApplicationCable::Channel
  # == Constants ============================================================
  NAME = ChatRoom::CHANNEL_NAME

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Connection ===========================================================
  def subscribed
    stream_from NAME
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    ActionCable.server.broadcast(NAME, { user_id: current_user&.id, action: 'left' })
  end

  # == Actions ==============================================================
  def joined(*)
    ActionCable.server.broadcast(NAME, { rooms: recent_rooms, open: chat_is_open, toggled_by: chat_toggled_by, action: 'joined' })
    Rails.redis.keys("chat_rooms.clients.*").each do |k|
      puts "#{k}: #{Rails.redis.get(k)}, #{Rails.redis.get(k).sub('.clients.', '.staff.')}"
      if Boolean.parse(Rails.redis.get(k)) && !Boolean.parse(Rails.redis.get(k).sub('.clients.', '.staff.'))
        room = ChatRoom.find_by(id: k.split(".").last)
        if room && !room.is_closed
          ActionCable.server.broadcast NAME, { action: 'agent-needed', uuid: room.uuid }
          ChatMessagesChannel.broadcast_to room, action: 'agent-check'
        end
      end
    end
  end

  def check(data)
    latest_update = recent_rooms.try(:maximum, :updated_at) || Time.zone.now
    last_check = Time.zone.parse(data['updated']) rescue Time.zone.now
    joined if last_check < latest_update
  end

  def availability(data)
    self.chat_is_open = data['open']

    ActionCable.server.broadcast(NAME, { open: chat_is_open, toggled_by: chat_toggled_by, action: 'availability' })
  end

  private
    def recent_rooms
      rooms = ChatRoom.where(is_closed: false).order(updated_at: :desc)
      if rooms.count < 20
        rooms
      else
        rooms.where(ChatRoom.arel_table[:updated_at].gt(2.hours.ago))
      end
    end

    def chat_is_open
      ChatRoom.chat_is_open
    end

    def chat_is_open=(value)
      ChatRoom.chat_is_open = value
      ChatRoom.chat_toggled_by = current_user
    end

    def chat_toggled_by
      ChatRoom.chat_toggled_by
    end
end
