class CreateUserUniformOrders < ActiveRecord::Migration[5.2]
  def change
    create_table :user_uniform_orders do |t|
      t.references :user, null: false, foreign_key: true
      t.references :submitter, null: false, foreign_key: { to_table: :users }
      t.references :sport, null: false, foreign_key: true

      t.money_integer :cost
      t.boolean :is_reorder, null: false, default: false

      t.text :jersey_size
      t.text :shorts_size

      t.integer :jersey_count, default: 1
      t.integer :shorts_count, default: 1

      t.integer :jersey_number
      t.integer :preferred_number_1
      t.integer :preferred_number_2
      t.integer :preferred_number_3

      t.datetime :submitted_to_shop_at
      t.datetime :paid_shop_at
      t.date :invoice_date

      t.date :shipped_date
      t.jsonb :shipping, null: false, default: {}

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :user_uniform_orders
  end
end
