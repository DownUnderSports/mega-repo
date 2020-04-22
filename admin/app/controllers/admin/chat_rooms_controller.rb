# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ChatRoomsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'internal'

    # == Pre/Post Flight Checks =============================================
    before_action :set_current_user_var

    # == Actions ============================================================
    def index
      @chat_rooms = authorize ChatRoom.order(created_at: :desc, id: :desc).limit(params[:limit] || 100).offset(params[:offset] || 0)
      respond_to do |f|
        f.html
        f.json do
          return render json: @chat_rooms
        end
      end
    end

    def show
      @chat_room = authorize ChatRoom.find_by(id: params[:id])
      respond_to do |f|
        f.html
        f.json do
          return render json: @chat_room || {}
        end
      end
    end

    def destroy
      @chat_room = authorize ChatRoom.find_by(id: params[:id])
      @chat_room.destroy
      redirect_to admin_chat_rooms_path
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def set_current_user_var
        @current_user ||= current_user || check_user
      end
  end
end
