class CreateTravelers < ActiveRecord::Migration[5.2]
  def change
    create_table :travelers do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :team, null: false, foreign_key: true
      t.money_integer :balance, null: false
      t.text :shirt_size
      t.date :departing_date
      t.text :departing_from
      t.date :returning_date
      t.text :returning_to
      t.text :bus
      t.text :wristband
      t.text :hotel
      t.boolean :has_ground_transportation, null: false, default: true
      t.boolean :has_lodging, null: false, default: true
      t.boolean :has_gbr, null: false, default: false
      t.boolean :own_flights, null: false, default: false
      t.date :cancel_date
      t.text :cancel_reason

      t.index [ :cancel_date ]
      t.index [ :departing_date ]
      t.index [ :balance ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :travelers
  end
end
