class CreateTravelerDebits < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_debits do |t|
      t.references :base_debit, null: false, foreign_key: { to_table: :traveler_base_debits }
      t.references :traveler, null: false, foreign_key: true
      t.references :assigner, foreign_key: { to_table: :users }
      t.money_integer :amount
      t.text :name
      t.text :description

      t.index [ :amount ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :traveler_debits
  end
end
