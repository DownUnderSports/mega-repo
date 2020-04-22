class AddMinimumPercentageToMeetingVideos < ActiveRecord::Migration[5.2]
  def up
    #==== GET INDEXES ===
    <<-SQL
      SELECT i.relname as indname,
             i.relowner as indowner,
             idx.indrelid::regclass
      FROM   pg_index as idx
      JOIN   pg_class as i
      ON     i.oid = idx.indexrelid
      JOIN   pg_am as am
      ON     i.relam = am.oid
      JOIN   pg_namespace as ns
      ON     ns.oid = i.relnamespace
      AND    ns.nspname = ANY(current_schemas(false))
      WHERE idx.indrelid::regclass::text = 'meeting_videos';
    SQL

    #===== MIGRATION ===

    execute "DROP TRIGGER audit_trigger_row ON meeting_videos;"

    execute "DROP TRIGGER audit_trigger_stm ON meeting_videos;"

    rename_table :meeting_videos, :old_meeting_videos

    create_table :meeting_videos do |t|
      t.meeting_category :category, null: false
      t.text :link, null: false
      t.interval :duration, null: false, default: 0
      t.exchange_rate_integer :minimum_percentage, null: false, default: StoreAsInt::ExchangeRate.new('0.25').value
      t.integer :sent, null: false, default: 0
      t.integer :viewed, null: false, default: 0
      t.jsonb :offer, null: false, default: {}
      t.text :offer_exceptions_array, null: false, array: true, default: []

      t.datetime :updated_at, null: false, default: -> { 'NOW()' }
    end

    execute <<-SQL
      INSERT INTO meeting_videos
      (
        id,
        category,
        link,
        duration,
        sent,
        viewed,
        offer,
        offer_exceptions_array,
        updated_at
      )
      SELECT
        id,
        category,
        link,
        duration,
        sent,
        viewed,
        offer,
        offer_exceptions_array,
        updated_at
      FROM old_meeting_videos
    SQL

    ActiveRecord::Base.connection.reset_pk_sequence!('meeting_videos')

    ActiveRecord::Base.connection.execute(
      <<-SQL
        SELECT DISTINCT
          tc.table_schema,
          tc.constraint_name,
          tc.table_name,
          kcu.column_name,
          ccu.table_schema AS foreign_table_schema,
          ccu.table_name AS foreign_table_name,
          ccu.column_name AS foreign_column_name
        FROM
          information_schema.table_constraints AS tc
          JOIN information_schema.key_column_usage AS kcu
            ON tc.constraint_name = kcu.constraint_name
            AND tc.table_schema = kcu.table_schema
          JOIN information_schema.constraint_column_usage AS ccu
            ON ccu.constraint_name = tc.constraint_name
            AND ccu.table_schema = tc.table_schema
        WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_meeting_videos';

      SQL
    ).each do |row|
      r = row.to_h.deep_symbolize_keys
      constraint_name = r[:constraint_name]
      execute <<-SQL
        ALTER TABLE "#{r[:table_schema]}"."#{r[:table_name]}"
          DROP CONSTRAINT "#{r[:constraint_name]}";
      SQL

      execute <<-SQL
        ALTER TABLE "#{r[:table_schema]}"."#{r[:table_name]}"
          ADD CONSTRAINT "#{r[:constraint_name]}"
          FOREIGN KEY (#{r[:column_name]})
          REFERENCES "#{r[:foreign_table_schema]}"."meeting_videos" (#{r[:foreign_column_name]})
          ON DELETE RESTRICT
      SQL
    end

    audit_table :meeting_videos
    drop_table :old_meeting_videos

    # begin
    #   Meeting::Video.where(category: 'I').each {|mv| mv.update(minimum_percentage: ('00:23:00'.to_i / mv.duration.to_i.to_d)) }
    # rescue
    #   puts $!.message
    # end

  end

  def down
    remove_column :meeting_videos, :minimum_percentage
  end
end
