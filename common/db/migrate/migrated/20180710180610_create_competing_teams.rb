class CreateCompetingTeams < ActiveRecord::Migration[5.2]
  def change
    create_table :competing_teams do |t|
      t.references :sport, null: false, foreign_key: true
      t.text :name, null: false
      t.text :letter, null: false

      t.index [ :name, :sport_id ], unique: true
      t.index [ :letter, :sport_id ], unique: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
