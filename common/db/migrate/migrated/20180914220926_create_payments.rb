class CreatePayments < ActiveRecord::Migration[5.2]
  def change
    create_table :payments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :shirt_order, foreign_key: true
      t.text :gateway_type, null: false, default: 'braintree'

      t.boolean :successful, null: false, default: false

      t.money_integer :amount, null: false

      t.text :category, null: false, default: 'account'
      t.text :remit_number, null: false, default: -> { "NOW()::date || '-CC'" }
      t.text :status
      t.text :transaction_type
      t.text :transaction_id

      t.jsonb :billing, null: false, default: {}
      t.jsonb :processor, null: false, default: {}
      t.jsonb :settlement, null: false, default: {}
      t.jsonb :gateway, null: false, default: {}
      t.jsonb :risk, null: false, default: {}

      t.boolean :anonymous, null: false, default: false
      
      t.index [ :gateway_type ], using: 'hash'
      t.index [ :transaction_id ], using: 'hash'
      t.index [ :category ], using: 'hash'
      t.index [ :category, :successful ]
      t.index [ :successful, :category ]
      t.index [ :billing ], using: 'gin'

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :payments
  end
end
