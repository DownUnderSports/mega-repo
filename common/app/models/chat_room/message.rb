# encoding: utf-8
# frozen_string_literal: true

# ChatRoom::Message description
class ChatRoom < ApplicationRecord
  class Message < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :chat_room, inverse_of: :messages
    belongs_to :user, optional: true, inverse_of: :chat_room_messages

    # == Validations ==========================================================

    # == Scopes ===============================================================
    default_scope { default_order(:created_at) }

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def serializable_hash(*)
      super.tap do |h|
        h['staff'] = self.user&.is_staff?
        h['user_name'] = self.user&.print_first_name_only
      end
    end
  end
end
