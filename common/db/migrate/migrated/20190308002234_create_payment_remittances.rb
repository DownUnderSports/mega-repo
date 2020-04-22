class CreatePaymentRemittances < ActiveRecord::Migration[5.2]
  def change
    create_table :payment_remittances do |t|
      t.text :remit_number
      t.boolean :recorded, null: false, default: false
      t.boolean :reconciled, null: false, default: false

      t.index :remit_number, unique: true
      t.index :recorded
      t.index :reconciled

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :payment_remittances
  end
end
