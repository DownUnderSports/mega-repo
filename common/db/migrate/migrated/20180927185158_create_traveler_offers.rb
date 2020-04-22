class CreateTravelerOffers < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_offers do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigner, foreign_key: { to_table: :users }
      t.text :rules,  null: :false, array: true, default: []
      t.money_integer :amount
      t.money_integer :minimum
      t.money_integer :maximum
      t.date :expiration_date
      t.text :name
      t.text :description

      t.index [ :amount ]
      t.index [ :minimum ]
      t.index [ :maximum ]

      t.timestamps default: -> { 'NOW()' }
    end
    add_index :traveler_offers, '((rules[1])::text) text_pattern_ops, amount', name: :index_traveler_offers_on_rules_and_amount

    audit_table :traveler_offers
  end
end
