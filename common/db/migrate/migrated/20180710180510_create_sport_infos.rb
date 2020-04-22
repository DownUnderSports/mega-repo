class CreateSportInfos < ActiveRecord::Migration[5.2]
  def change
    create_table :sport_infos do |t|
      t.references :sport, null: false, foreign_key: true
      t.text :title, null: false
      t.text :tournament, null: false
      t.integer :first_year, null: false
      t.text :departing_dates, null: false
      t.text :returning_dates, null: false
      t.text :team_count, null: false
      t.text :team_size, null: false
      t.text :description, null: false
      t.text :bullet_points_array, null: false, array: true, default: []
      t.text :programs_array, null: false, array: true, default: []
      t.text :background_image
      t.text :additional

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
