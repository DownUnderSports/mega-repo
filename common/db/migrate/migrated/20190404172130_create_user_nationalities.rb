class CreateUserNationalities < ActiveRecord::Migration[5.2]
  def change
    create_table :user_nationalities do |t|
      t.text :code, null: false
      t.text :country
      t.text :nationality
      t.boolean :visable, null: false, default: false

      t.index [ :code ], unique: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
