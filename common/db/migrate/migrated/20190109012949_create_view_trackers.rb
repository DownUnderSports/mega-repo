class CreateViewTrackers < ActiveRecord::Migration[5.2]
  def change
    create_table :view_trackers do |t|
      t.text :name, null: false
      t.boolean :running, null: false, default: false

      t.index [ :name ], unique: true

      t.datetime :last_refresh
    end
  end
end
