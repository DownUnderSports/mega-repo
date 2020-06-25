class CreateUserRecaps < ActiveRecord::Migration[5.2]
  def change
    create_table :user_recaps do |t|
      t.references :user, null: false, foreign_key: true
      t.text :log
      t.integer :total_audits, default: 0
      t.integer :users_modified, default: 0
      t.integer :notes_made, default: 0
      t.integer :package_modifications, default: 0

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
