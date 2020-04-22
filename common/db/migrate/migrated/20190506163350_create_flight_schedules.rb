class CreateFlightSchedules < ActiveRecord::Migration[5.2]
  def change
    create_table :flight_schedules do |t|
      t.references :parent_schedule, foreign_key: { to_table: :flight_schedules }
      t.references :verified_by,     foreign_key: { to_table: :users }

      t.text :pnr, null: false
      t.text :carrier_pnr
      t.text :operator
      t.text :route_summary, null: false
      t.text :booking_reference

      t.money_integer :amount
      t.integer :seats_reserved, null: false, default: 0
      t.integer :names_assigned, null: false, default: 0

      t.text :original_value

      t.index [ :pnr ],           unique: true
      t.index [ :route_summary ], unique: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :flight_schedules
  end
end
