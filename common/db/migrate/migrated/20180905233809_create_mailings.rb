class CreateMailings < ActiveRecord::Migration[5.2]
  def change
    create_table :mailings do |t|
      t.references :user, foreign_key: true
      t.text :category
      t.date :sent

      t.boolean :explicit, null: false, default: false
      t.boolean :printed, null: false, default: false
      t.boolean :is_home, null: false, default: false
      t.boolean :is_foreign, null: false, default: false
      t.boolean :auto, null: false, default: false
      t.boolean :failed, null: false, default: false

      t.text :street, null: false
      t.text :street_2
      t.text :street_3
      t.text :city, null: false
      t.text :state, null: false
      t.text :zip, null: false
      t.text :country, default: 'USA'

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
