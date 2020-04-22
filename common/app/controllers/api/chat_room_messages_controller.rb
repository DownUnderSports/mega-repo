# encoding: utf-8
# frozen_string_literal: true

module API
  class ChatRoomMessagesController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def create
      chat_room = ChatRoom.find_by(id: params[:id])
      message = chat_room.messages.create!(message_params)

      ChatMessagesChannel.broadcast_to chat_room, { message: message.as_json, action: 'chat' }

      head :ok
    rescue
      head :error
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
