class CreateImportErrors < ActiveRecord::Migration[5.2]
  def change
    create_table :import_errors do |t|
      t.text :upload_type, null: false
      t.jsonb :values, null: false, default: {}

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
