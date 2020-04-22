class ChatMessagesChannel < ApplicationCable::Channel
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Connection ===========================================================
  def subscribed
    puts "UUID: #{params[:uuid]}"
    str = stream_for current_room
    track_presence :incr
    str
  end

  def unsubscribed
    track_presence :decr

    # Any cleanup needed when channel is unsubscribed
    ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { uuid: current_room.uuid, action: 'left' })

    unless current_user&.is_staff?
      broadcast_data action: 'user-disconnected'
    end
  end

  # == Actions ==============================================================
  def agent(*)
    ActionCable.server.broadcast ChatRoom::CHANNEL_NAME, { action: 'agent-needed', uuid: current_room.uuid }
    broadcast_data action: 'agent-check'
  end

  def available(*)
    if current_user&.is_staff?
      broadcast_data action: 'agent-found', current_user: current_user

      ActionCable.server.broadcast ChatRoom::CHANNEL_NAME, { action: 'agent-found', uuid: current_room.uuid }
    else
      touch_room

      broadcast_data action: 'active', current_user: current_user
    end
  end

  def chat(data)
    @data = data&.to_h

    agent unless current_user&.is_staff?

    available

    text = data['message'].to_s.strip
    if text.present?
      message = current_room.messages.create!(message: text, user_id: current_user&.id)

      broadcast_data message: message.as_json, action: 'chat'

      ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { uuid: current_room.uuid, last_message: message.updated_at.to_s, action: 'new-message' })
    else
      raise "No Message Sent"
    end
  rescue
    ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { uuid: current_room.uuid, error: [$!.message, *$!.backtrace], data: @data || {}, action: 'error' })
    puts $!.message
    puts $!.backtrace
  end

  def close(*)
    current_room.update(is_closed: true)

    broadcast_data action: 'closed'
    ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { uuid: current_room.uuid, action: 'closed' })
    keys = Rails.redis.keys("chat_rooms.*.#{current_room.uuid}")
    Rails.redis.del(keys) if keys.present?
  end

  def disconnected(*)
    close if current_room.updated_at > 10.minutes.ago
  end

  def joined(*)
    touch_room

    broadcast_data messages: current_room.messages.as_json, user_id: current_user&.id, staff: current_user&.is_staff?, closed: current_room.is_closed, action: 'joined'

    unless current_user&.is_staff? || current_room.is_closed
      StaffMailer.
        with(uuid: current_room.uuid).
        chat_waiting.
        deliver_later(wait_until: 2.minutes.from_now, queue: :staff_mailer)
    end
  end

  def inactive(*)
    if current_user&.is_staff? && current_room.update(is_closed: true)
      current_room.reload
      broadcast_data messages: current_room.messages.as_json, action: 'marked-inactive'

      ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { room: current_room, open: ChatRoom.chat_is_open, toggled_by: ChatRoom.chat_toggled_by, action: 'updated' })
    end
  end

  def meta(data)
    available
    params = {}
    if data['email'].present?
      params[:email] = data['email']
    end
    if data['phone'].present?
      params[:phone] = data['phone']
    end

    ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { room: current_room, open: ChatRoom.chat_is_open, toggled_by: ChatRoom.chat_toggled_by, action: 'updated' }) if params.present? && current_room.update(params)
  end

  def ping(*)
    broadcast_data action: 'ping'
  end

  def typing(data)
    available
    active = Boolean.parse(data['active'])
    touch_room if current_room.updated_at < 2.minutes.ago
    broadcast_data action: 'typing', id: current_user&.id, staff: !!current_user&.is_staff?, active: active
  end

  def verify(*)
    track_presence :incr
  end

  private
    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def broadcast_data(data)
      self.class.broadcast_to current_room, data
    end

    def current_room
      @chat_room ||= ChatRoom.find_by!(id: params[:uuid])
    rescue
      ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { uuid: params[:uuid], action: 'closed' })
      keys = Rails.redis.keys("chat_rooms.*.#{params[:uuid]}")
      Rails.redis.del(keys) if keys.present?
      ChatRoom.new(id: params[:uuid])
    end

    def track_presence(dir = :incr)
      current_room.track_presence dir, current_user
    end

    def touch_room
      current_room&.touch unless current_user&.is_staff?
    end

end
