class CreateStudentLists < ActiveRecord::Migration[5.2]
  def change
    create_table :student_lists do |t|
      t.date :sent, null: false
      t.date :received

      t.index [ :sent ], unique: true
    end

    audit_table :student_lists
  end
end
