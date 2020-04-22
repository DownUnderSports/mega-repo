class CreateJoinTableTravelerBusesTravelers < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_buses_travelers, id: false do |t|
      t.references :traveler, null: false, foreign_key: true
      t.references :bus, null: false, foreign_key: { to_table: :traveler_buses }

      t.index [ :traveler_id, :bus_id ], unique: true
    end

    audit_table :traveler_buses_travelers
  end
end
