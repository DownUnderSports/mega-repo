class CreateAthletes < ActiveRecord::Migration[5.2]
  def change
    create_table :athletes do |t|
      t.references :school, foreign_key: true
      t.references :source, foreign_key: true
      t.references :sport, foreign_key: true
      t.references :competing_team, foreign_key: true
      t.references :referring_coach, foreign_key: { to_table: :coaches }
      t.integer :grad
      t.date :student_list_date
      t.date :respond_date
      t.text :original_school_name
      t.integer :txfr_school_id

      t.index [ :student_list_date ]
      t.index [ :respond_date ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :athletes
  end
end
