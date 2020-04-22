class CreateSports < ActiveRecord::Migration[5.2]
  def change
    create_table :sports do |t|
      t.text :abbr, null: false
      t.text :full, null: false
      t.text :abbr_gender, null: false
      t.text :full_gender, null: false

      t.boolean :is_numbered, null: false, default: false

      t.index [ :abbr ], unique: false
      t.index [ :full ], unique: false
      t.index [ :abbr_gender ], unique: true
      t.index [ :full_gender ], unique: true
    end

    audit_table :sports
  end
end
