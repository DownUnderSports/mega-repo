class CreateSources < ActiveRecord::Migration[5.2]
  def change
    create_table :sources do |t|
      t.text :name, null: false
      t.index [ :name ], unique: true
    end

    audit_table :sources
  end
end
