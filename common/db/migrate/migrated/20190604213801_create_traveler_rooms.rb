class CreateTravelerRooms < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_rooms do |t|
      t.references :traveler, null: false, foreign_key: true
      t.references :hotel, null: false, foreign_key: { to_table: :traveler_hotels }

      t.text :number
      t.date :check_in_date, null: false
      t.date :check_out_date, null: false

      t.index [
        :traveler_id,
        :hotel_id,
        :check_in_date,
        :check_out_date
      ], unique: true, name: :index_traveler_rooms_on_hotel_dates

      t.index [ :check_in_date ]
      t.index [ :check_out_date ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :traveler_rooms
  end
end
