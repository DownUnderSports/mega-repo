class CreateUserForwardedIds < ActiveRecord::Migration[5.2]
  def change
    create_table :user_forwarded_ids, id: false do |t|
      t.text :original_id, null: false
      t.text :dus_id

      t.index [ :original_id ], unique: true
      t.index [ :dus_id ]
    end
  end
end
