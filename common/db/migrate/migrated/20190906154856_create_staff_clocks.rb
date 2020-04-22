class CreateStaffClocks < ActiveRecord::Migration[5.2]
  def change
    create_table :staff_clocks do |t|
      t.references :staff, null: false, foreign_key: true

      t.timestamps default: -> { 'NOW()' }
    end
  end
end
