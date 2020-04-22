class CreateImportAthletes < ActiveRecord::Migration[5.2]
  def change
    create_table :import_athletes do |t|
      t.text :first, null: false
      t.text :last, null: false
      t.text :gender, null: false
      t.integer :grad, null: false
      t.text :stats, null: false
      t.jsonb :event_list, null: false, default: {}
      t.text :school_name, null: false
      t.text :school_class
      t.references :school, foreign_key: true
      t.references :state, foreign_key: true
      t.references :sport, foreign_key: true
      t.text :source_name, null: false

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
