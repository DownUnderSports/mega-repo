class CreateChatRoomMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :chat_room_messages do |t|
      t.references :chat_room, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.text :message

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
