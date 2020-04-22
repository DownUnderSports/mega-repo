class CreateMeetingVideos < ActiveRecord::Migration[5.2]
  def change
    create_table :meeting_videos do |t|
      t.meeting_category :category, null: false
      t.text :link, null: false
      t.interval :duration, null: false, default: 0
      t.integer :sent, null: false, default: 0
      t.integer :viewed, null: false, default: 0
      t.jsonb :offer, null: false, default: {}
      t.text :offer_exceptions_array, null: false, array: true, default: []

      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end

    audit_table :meeting_videos
  end
end
