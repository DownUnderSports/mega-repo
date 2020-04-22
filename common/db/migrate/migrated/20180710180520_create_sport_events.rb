class CreateSportEvents < ActiveRecord::Migration[5.2]
  def change
    create_table :sport_events do |t|
      t.references :sport, null: false, foreign_key: true
      t.text :name
      t.text :pattern

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
