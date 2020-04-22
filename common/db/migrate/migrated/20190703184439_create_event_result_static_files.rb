class CreateEventResultStaticFiles < ActiveRecord::Migration[5.2]
  def change
    create_table :event_result_static_files do |t|
      t.references :event_result, null: false, foreign_key: true
      t.text :name, null: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :event_result_static_files
  end
end
