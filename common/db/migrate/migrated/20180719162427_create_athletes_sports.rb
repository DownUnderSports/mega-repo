class CreateAthletesSports < ActiveRecord::Migration[5.2]
  def change
    create_table :athletes_sports do |t|
      t.references :athlete, foreign_key: true
      t.references :sport, foreign_key: true
      t.integer :rank
      t.text :main_event
      t.text :main_event_best
      t.text :stats
      t.boolean :invited, index: true, null: false, default: false
      t.date :invited_date, index: true
      t.text :height
      t.text :weight
      t.text :handicap
      t.text :handicap_category
      t.integer :years_played
      t.boolean :special_teams, null: false, default: false
      t.text :positions_array, null: false, array: true, default: []
      t.boolean :submitted_info, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :athletes_sports
  end
end
