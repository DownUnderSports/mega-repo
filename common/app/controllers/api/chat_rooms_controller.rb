# encoding: utf-8
# frozen_string_literal: true

module API
  class ChatRoomsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      raise "Chat Services are currently closed, please check back during normal business hours." unless ChatRoom.chat_is_open
      chat_room = nil
      if(Boolean.parse(params[:reopen]))
        chat_room = ChatRoom.find_by!(id: params[:uuid])
        chat_room.update!(is_closed: false)
        ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { room: chat_room.reload, open: ChatRoom.chat_is_open, toggled_by: ChatRoom.chat_toggled_by, action: 'updated' })
      else
        chat_room = ChatRoom.create!(chat_room_params).reload
        ActionCable.server.broadcast(ChatRoom::CHANNEL_NAME, { room: chat_room, open: ChatRoom.chat_is_open, toggled_by: ChatRoom.chat_toggled_by, action: 'created' })
      end
      return render json: chat_room
    rescue
      return not_authorized($!.message, 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
    def chat_room_params
      params.require(:chat_room).permit(:name, :email, :phone)
    end
  end
end
