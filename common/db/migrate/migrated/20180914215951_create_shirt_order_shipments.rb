class CreateShirtOrderShipments < ActiveRecord::Migration[5.2]
  def change
    create_table :shirt_order_shipments do |t|
      t.references :shirt_order, null: false, foreign_key: true
      t.jsonb :shirts, null: false, default: {}
      t.integer :shirts_count, null: false, default: 0
      t.date :sent, null: false, default: -> { 'NOW()::date' }
      t.jsonb :shipped_to, null: false, default: {}
      t.boolean :failed, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :shirt_order_shipments
  end
end
