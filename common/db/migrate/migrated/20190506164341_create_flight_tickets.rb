class CreateFlightTickets < ActiveRecord::Migration[5.2]
  def change
    create_table :flight_tickets do |t|
      t.references :schedule, null: false, foreign_key: { to_table: :flight_schedules }
      t.references :traveler, null: false, foreign_key: true
      t.boolean :ticketed, null: false, default: false
      t.boolean :required, null: false, default: false
      t.text :ticket_number

      t.boolean :is_checked_in, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :flight_tickets
  end
end
