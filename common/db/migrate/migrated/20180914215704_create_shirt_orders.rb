class CreateShirtOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :shirt_orders do |t|
      t.money_integer :total_price, null: false, default: 0
      t.integer :shirts_ordered, null: false, default: 0
      t.integer :shirts_sent, null: false, default: 0
      t.jsonb :shipping, null: false, default: {}
      t.boolean :complete, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :shirt_orders
  end
end
