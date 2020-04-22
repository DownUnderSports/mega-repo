class CreateTravelerBaseDebits < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_base_debits do |t|
      t.money_integer :amount
      t.text :name, null: false
      t.text :description
      t.boolean :is_default, null: false, default: false

      t.index [ :name ], using: 'gin'
      t.index [ :name, :amount ]
      t.index [ :is_default ]

      t.timestamps default: -> { 'NOW()' }
    end
    
    audit_table :traveler_base_debits
  end
end
