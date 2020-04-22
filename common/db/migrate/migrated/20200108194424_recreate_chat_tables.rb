class RecreateChatTables < ActiveRecord::Migration[5.2]
  def up
    drop_table :chat_room_messages
    drop_table :chat_rooms

    create_table :chat_rooms do |t|
      t.text :uuid, null: false, default: -> { 'gen_random_uuid()' }
      t.text :name
      t.text :email
      t.text :phone
      t.boolean :is_closed, null: false, default: false

      t.index [ :uuid ], unique: true
      t.index [ :is_closed ]

      t.timestamps default: -> { 'NOW()' }
    end

    create_table :chat_room_messages do |t|
      t.references :chat_room, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.text :message

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
