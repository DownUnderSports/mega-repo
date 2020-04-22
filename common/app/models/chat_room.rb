# encoding: utf-8
# frozen_string_literal: true

# ChatRoom description
class ChatRoom < ApplicationRecord
  # == Constants ============================================================
  CHANNEL_NAME = "chat_rooms_channel"

  # == Attributes ===========================================================
  attribute :uuid, :text

  # == Extensions ===========================================================

  # == Relationships ========================================================
  has_many :messages, class_name: 'ChatRoom::Message',
                      dependent: :destroy,
                      inverse_of: :chat_room


  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.verify_connections
    where(is_closed: false).order(:id).split_batches_values(preserve_order: true) do |room|
      room.reset_presence
      ChatMessagesChannel.broadcast_to room, action: "verify", timestamp: Time.zone.now
    end
    ActionCable.server.broadcast CHANNEL_NAME, { action: 'verify', timestamp: Time.zone.now }
  end

  def self.chat_is_open
    Boolean.parse Rails.redis.get('chat_is_open')
  end

  def self.chat_is_open=(value)
    Rails.redis.set('chat_is_open', Boolean.parse(value) ? 1 : 0)
  end

  def self.chat_toggled_by
    Rails.redis.get('chat_toggled_by') || auto_worker.print_names
  end

  def self.chat_toggled_by=(user)
    Rails.redis.set('chat_toggled_by', (user || auto_worker).print_names)
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def uuid
    self.id
  end

  def uuid=(value)
    self.id = value
  end

  def url
    "https://admin.downundersports.com/admin/chat/#{self.uuid}"
  end

  def serializable_hash(*)
    super.tap do |h|
      if self.id.present?
        h['uuid'] = self.id
        h['connected_clients'] = get_count "clients"
        h['connected_staff'] = get_count "staff"
        h['total_connected'] = get_count "total"
        h['lastMessage'] = messages.try(:maximum, :created_at)
      end
    end
  end

  def get_count(k)
    Rails.redis.get(presence_tracker(k)).to_i
  end

  def reset_presence
    %w[ clients staff total ].each do |k|
      Rails.redis.set presence_tracker(k), 0
    end
  end

  def track_presence(dir = :incr, user)
    fix_invalid if dir == :incr
    Rails.redis.__send__(dir, presence_tracker("clients")) unless user&.is_staff?
    Rails.redis.__send__(dir, presence_tracker("staff")) if user&.is_staff?
    Rails.redis.__send__(dir, presence_tracker("total"))
    fix_invalid if dir == :decr

    notify_presence_changes
  end

  def fix_invalid
    %w[ clients staff total ].each do |k|
      if Rails.redis.get(presence_tracker(k)).to_i < 0
        Rails.redis.del presence_tracker k
      end
    end
  end

  def presence_tracker(category = "clients")
    "#{self.class::CHANNEL_NAME}.#{category}.#{self.uuid}"
  end

  def notify_presence_changes
    ActionCable.server.broadcast self.class::CHANNEL_NAME, { action: 'presence', room: self.as_json, open: chat_is_open, toggled_by: chat_toggled_by }
  end

  def chat_is_open
    self.class.chat_is_open
  end

  def chat_toggled_by
    self.class.chat_toggled_by
  end

end
