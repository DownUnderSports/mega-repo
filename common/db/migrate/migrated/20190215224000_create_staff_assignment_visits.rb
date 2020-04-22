class CreateStaffAssignmentVisits < ActiveRecord::Migration[5.2]
  def change
    create_table :staff_assignment_visits do |t|
      t.references :assignment, null: false, foreign_key: { to_table: :staff_assignments }

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
