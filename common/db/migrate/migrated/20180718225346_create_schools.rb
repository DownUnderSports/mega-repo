class CreateSchools < ActiveRecord::Migration[5.2]
  def change
    create_table :schools do |t|
      t.text :pid, null: false
      t.references :address, foreign_key: true
      t.text :name, null: false
      t.boolean :allowed, null: false, default: true
      t.boolean :allowed_home, null: false, default: true
      t.boolean :closed, null: false, default: false

      t.index [ :pid ], unique: true
      t.index [ :allowed ]
      t.index [ :allowed_home ]
      t.index [ :closed ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :schools

    reversible do |d|
      d.up do
        execute "CREATE INDEX schools_name_search_idx ON schools using gin (name gin_trgm_ops);"
      end

      d.down do
        execute "DROP INDEX schools_name_search_idx;"
      end
    end
  end
end
