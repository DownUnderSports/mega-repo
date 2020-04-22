class CreateMeetingVideoViews < ActiveRecord::Migration[5.2]
  def change
    create_table :meeting_video_views do |t|
      t.references :video, null: false, foreign_key: { to_table: :meeting_videos }
      t.references :user, null: false, foreign_key: true
      t.references :athlete, foreign_key: true
      t.boolean :watched, null: false, default: false
      t.interval :duration, null: false, default: 0
      t.text :questions, null: false, array: true, default: []
      t.datetime :first_viewed_at
      t.datetime :first_watched_at
      t.datetime :last_viewed_at
      t.boolean :gave_offer, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :meeting_video_views
  end
end
