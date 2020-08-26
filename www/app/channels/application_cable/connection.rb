# encoding: utf-8
# frozen_string_literal: true

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        verified_user = User.find_by(id: cookies.encrypted[:current_user_id].presence || cookies.encrypted[:current_user_id_legacy])
      end
  end
end
