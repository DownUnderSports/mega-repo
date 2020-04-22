class CreatePaymentItems < ActiveRecord::Migration[5.2]
  def change
    create_table :payment_items do |t|
      t.references :payment, null: false, foreign_key: true
      t.references :traveler, foreign_key: true
      t.money_integer :amount, null: false, default: 0
      t.money_integer :price, null: false, default: 0
      t.integer :quantity, null: false, default: 1
      t.text :name, null: false, default: 'Account Payment'
      t.text :description

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :payment_items
  end
end
