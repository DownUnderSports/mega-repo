class AddLastViewedAtToMeetingVideoViews < ActiveRecord::Migration[5.2]
  def up
    unless Meeting::Video::View.column_names.include? 'last_viewed_at'
      change_table :meeting_video_views do |t|
        t.rename :gave_offer, :was_gave_offer
        t.rename :created_at, :was_created_at
        t.rename :updated_at, :was_updated_at

        t.datetime :last_viewed_at
        t.boolean :gave_offer, null: false, default: false

        t.datetime :created_at, null: false, default: -> { 'NOW()' }
        t.datetime :updated_at, null: false, default: -> { 'NOW()' }
      end

      execute <<-SQL
        UPDATE meeting_video_views
        SET
          gave_offer = was_gave_offer,
          created_at = was_created_at,
          updated_at = was_updated_at,
          last_viewed_at = CASE
            WHEN (duration > '0 seconds'::interval) THEN was_updated_at
            WHEN (watched = 't') THEN was_updated_at
            ELSE NULL
          END
      SQL

      remove_column :meeting_video_views, :was_gave_offer
      remove_column :meeting_video_views, :was_created_at
      remove_column :meeting_video_views, :was_updated_at
    end
  end
end
