class CreateTravelerHotels < ActiveRecord::Migration[5.2]
  def change
    create_table :traveler_hotels do |t|
      t.text :name, null: false
      t.references :address, null: false, foreign_key: true
      t.text :phone
      t.jsonb :contacts, null: false, default: []

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :traveler_hotels
  end
end
