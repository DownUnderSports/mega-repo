class CreateStaffAssignments < ActiveRecord::Migration[5.2]
  def change
    create_table :staff_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigned_to, null: false, foreign_key: { to_table: :users }
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }

      t.text :reason, default: -> { "'Follow Up'" }

      t.boolean :completed, null: false, default: false
      t.boolean :unneeded, null: false, default: false
      t.boolean :reviewed, null: false, default: false
      t.boolean :locked, null: false, default: false

      t.datetime :completed_at
      t.datetime :unneeded_at
      t.datetime :reviewed_at

      t.date :follow_up_date

      t.index [ :reason ]

      t.timestamps default: -> { 'NOW()' }
    end
    audit_table :staff_assignments
  end
end
