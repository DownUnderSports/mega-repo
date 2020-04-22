class CreateTravelerCredits < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_credits do |t|
      t.references :traveler, null: false, foreign_key: true
      t.references :assigner, foreign_key: { to_table: :users }
      t.money_integer :amount
      t.text :name, null: false
      t.text :description

      t.index [ :amount ]
      t.index [ :name ], using: 'gin'
      t.index [ :name, :amount ]

      t.timestamps default: -> { 'NOW()' }
    end
    
    audit_table :traveler_credits
  end
end
