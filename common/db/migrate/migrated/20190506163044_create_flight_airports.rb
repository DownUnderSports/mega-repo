class CreateFlightAirports < ActiveRecord::Migration[5.2]
  def change
    create_table :flight_airports do |t|
      t.text :code,    null: false
      t.text :name,    null: false
      t.text :carrier, null: false, default: 'qantas'

      t.money_integer :cost

      t.text :location_override
      t.references :address,    foreign_key: true
      t.integer    :tz_offset,  null: false, default: 0
      t.boolean    :dst,        null: false, default: true

      t.boolean :preferred,  null: false, default: false
      t.boolean :selectable, null: false, default: true

      t.date :track_departing_date
      t.date :track_returning_date

      t.index [ :code ],       unique: true
      t.index [ :name ],       unique: false
      t.index [ :carrier ],    unique: false
      t.index [ :dst ],        unique: false
      t.index [ :preferred ],  unique: false
      t.index [ :selectable ], unique: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :flight_airports
  end
end
