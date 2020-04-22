class CreateParticipants < ActiveRecord::Migration[5.2]
  def change
    create_table :participants do |t|
      t.text :name
      t.gender :gender, null: false, index: true, default: 'U'
      t.references :state, null: false, foreign_key: true
      t.references :sport, null: true, foreign_key: true
      t.text :sport_name
      t.text :school
      t.integer :fundraising_time
      t.integer :trip_cost
      t.text :category, default: 'athlete'
      t.text :year, default: 2018

      t.index [ :category, :state_id ]

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
