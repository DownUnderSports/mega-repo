class CreateImportMatches < ActiveRecord::Migration[5.2]
  def change
    create_table :import_matches do |t|
      t.text :name, null: false
      t.references :school, foreign_key: true
      t.references :state, foreign_key: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
