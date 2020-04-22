class CreateUserMessages < ActiveRecord::Migration[5.2]
  def change
    create_table :user_messages do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.references :staff, null: false, foreign_key: true, index: true
      t.text :type, null: false, index: true
      t.text :category, null: false, index: true
      t.text :reason, null: false, index: true, default: -> { "'other'" }
      t.text :message, null: false
      t.boolean :reviewed, null: false, default: false, index: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
