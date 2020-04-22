class CreateTeams < ActiveRecord::Migration[5.2]
  def change
    create_table :teams do |t|
      t.text :name
      t.references :sport, null: false, foreign_key: true
      t.references :state, null: false, foreign_key: true
      t.references :competing_team, foreign_key: true
      t.date :departing_date
      t.date :returning_date
      t.date :gbr_date
      t.integer :gbr_seats
      t.text :default_bus
      t.text :default_wristband
      t.text :default_hotel

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
