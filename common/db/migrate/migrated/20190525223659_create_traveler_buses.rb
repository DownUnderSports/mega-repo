class CreateTravelerBuses < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_buses do |t|
      t.references :sport, null: false, foreign_key: true
      t.references :hotel, foreign_key: { to_table: :traveler_hotels }

      t.integer :capacity, null: false, default: 0

      t.text :color, null: false
      t.text :name, null: false
      t.text :details

      t.index [ :color ]
      t.index [ :name ]
      t.index [ :sport_id, :color, :name ], unique: true

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :traveler_buses
  end
end
