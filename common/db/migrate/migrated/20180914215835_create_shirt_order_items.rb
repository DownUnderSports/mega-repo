class CreateShirtOrderItems < ActiveRecord::Migration[5.2]
  def change
    create_table :shirt_order_items do |t|
      t.references :shirt_order, null: false, foreign_key: true
      t.text :size, null: false
      t.boolean :is_youth, null: false, default: false
      t.integer :quantity, null: false, default: 0
      t.money_integer :price, null: false, default: 0
      t.integer :sent_count, null: false, default: 0
      t.boolean :complete, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :shirt_order_items
  end
end
