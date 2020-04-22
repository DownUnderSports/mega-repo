class CreateChatRooms < ActiveRecord::Migration[5.2]
  def change
    create_table :chat_rooms do |t|
      t.text :uuid, null: false, default: -> { 'gen_random_uuid()' }
      t.text :name
      t.text :email
      t.text :phone

      t.index [ :uuid ], unique: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
