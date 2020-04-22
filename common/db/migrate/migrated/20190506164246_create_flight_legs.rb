class CreateFlightLegs < ActiveRecord::Migration[5.2]
  def change
    create_table :flight_legs do |t|
      t.references :schedule, null: false, foreign_key: { to_table: :flight_schedules }
      t.text :flight_number

      t.references :departing_airport, null: false, foreign_key: { to_table: :flight_airports }
      t.datetime :departing_at, null: false

      t.references :arriving_airport, null: false, foreign_key: { to_table: :flight_airports }
      t.datetime :arriving_at, null: false

      t.boolean :overnight, null: false, default: false
      t.boolean :is_subsidiary, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :flight_legs
  end
end
