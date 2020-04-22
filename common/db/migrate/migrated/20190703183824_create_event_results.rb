class CreateEventResults < ActiveRecord::Migration[5.2]
  def change
    create_table :event_results do |t|
      t.references :sport, null: false, foreign_key: true
      t.text :name, null: false
      t.jsonb :data, null: false, default: {}

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :event_results
  end
end
