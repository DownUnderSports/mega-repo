class CreateCoaches < ActiveRecord::Migration[5.2]
  def change
    create_table :coaches do |t|
      t.references :school, null: false, foreign_key: true
      t.references :head_coach, foreign_key: { to_table: :coaches }
      t.references :sport, foreign_key: true
      t.references :competing_team, foreign_key: true
      t.boolean :checked_background, null: false, default: false
      t.integer :deposits, null: false, default: 0
      t.text :polo_size

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :coaches
  end
end
