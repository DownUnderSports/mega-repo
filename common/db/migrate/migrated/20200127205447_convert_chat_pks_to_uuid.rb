class ConvertChatPksToUuid < ActiveRecord::Migration[5.2]
  def up
    id_col = ChatRoom.columns.first
    unless (id_col.name == "id") && (id_col.type != :integer)
      rename_table :chat_room_messages, :old_room_messages
      rename_table :chat_rooms, :old_rooms

      create_table :chat_rooms, id: :uuid do |t|
        t.text :name
        t.text :email
        t.text :phone
        t.boolean :is_closed, null: false, default: false

        t.index [ :is_closed ]

        t.timestamps default: -> { 'NOW()' }
      end

      create_table :chat_room_messages do |t|
        t.references :chat_room, null: false, foreign_key: true, type: :uuid
        t.references :user, foreign_key: true
        t.text :message

        t.timestamps default: -> { 'NOW()' }
      end

      execute <<-SQL
        INSERT INTO chat_rooms
        (
          id,
          name,
          email,
          phone,
          is_closed,
          created_at,
          updated_at
        )
        SELECT
          uuid::uuid,
          name,
          email,
          phone,
          is_closed,
          created_at,
          updated_at
        FROM old_rooms
      SQL

      execute <<-SQL
        INSERT INTO chat_room_messages
        (
          id,
          chat_room_id,
          user_id,
          message,
          created_at,
          updated_at
        )
        SELECT
          old_room_messages.id,
          old_rooms.uuid::uuid,
          old_room_messages.user_id,
          old_room_messages.message,
          old_room_messages.created_at,
          old_room_messages.updated_at
        FROM old_room_messages
        INNER JOIN old_rooms
        ON old_rooms.id = old_room_messages.chat_room_id
      SQL

      User::Message.
        where("message ilike ?", "%chat/_%").
        split_batches_values do |message|
          message.message.gsub!(/[^\s]+\/chat\//, "https://authenticate.downundersports.com/admin/chat_rooms/")
          message.save
        end

      ActiveRecord::Base.connection.reset_pk_sequence!('chat_room_messages')

      drop_table :old_room_messages
      drop_table :old_rooms
    end
  end
end
