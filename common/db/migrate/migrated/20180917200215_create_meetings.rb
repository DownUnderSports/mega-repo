class CreateMeetings < ActiveRecord::Migration[5.2]
  def change
    create_table :meetings do |t|
      t.meeting_category :category, null: false
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.references :tech, null: false, foreign_key: { to_table: :users }
      t.datetime :start_time, null: false
      t.interval :duration, null: false, default: 0
      t.integer :registered, null: false, default: 0
      t.integer :attended, null: false, default: 0
      t.integer :represented_registered, null: false, default: 0
      t.integer :represented_attended, null: false, default: 0
      t.text :webinar_uuid
      t.text :session_uuid
      t.text :join_link
      t.text :recording_link
      t.text :notes
      t.text :questions
      t.jsonb :offer, null: false, default: {}
      t.text :offer_exceptions_array, null: false, array: true, default: []

      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end
    
    audit_table :meetings
  end
end
