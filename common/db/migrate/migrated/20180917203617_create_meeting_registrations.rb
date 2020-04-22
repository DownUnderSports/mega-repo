class CreateMeetingRegistrations < ActiveRecord::Migration[5.2]
  def change
    create_table :meeting_registrations do |t|
      t.references :meeting, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :athlete, foreign_key: true
      t.boolean :attended, null: false, default: false
      t.interval :duration, null: false, default: 0
      t.text :questions

      t.timestamps default: -> { 'NOW()' }
    end
    audit_table :meeting_registrations
  end
end
