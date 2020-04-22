class AddReturningDatesToSportInfos < ActiveRecord::Migration[5.2]
  def up
    unless Sport::Info.column_names.include? 'returning_dates'
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
        WHERE idx.indrelid::regclass::text = 'sport_infos';
      SQL

      #===== MIGRATION ===

      rename_table :sport_infos, :old_sport_infos

      create_table :sport_infos do |t|
        t.references :sport, null: false, foreign_key: true
        t.text :title, null: false
        t.text :tournament, null: false
        t.integer :first_year, null: false
        t.text :departing_dates, null: false
        t.text :returning_dates, null: false
        t.text :team_count, null: false
        t.text :team_size, null: false
        t.text :description, null: false
        t.text :bullet_points_array, null: false, array: true, default: []
        t.text :programs_array, null: false, array: true, default: []
        t.text :background_image
        t.text :additional

        t.timestamps default: -> { 'NOW()' }
      end

      execute <<-SQL
        INSERT INTO sport_infos
        (
          id,
          sport_id,
          title,
          tournament,
          first_year,
          departing_dates,
          returning_dates,
          team_count,
          team_size,
          description,
          bullet_points_array,
          programs_array,
          background_image,
          additional,
          created_at,
          updated_at
        )
        SELECT
          id,
          sport_id,
          title,
          tournament,
          first_year,
          departing_dates,
          departing_dates,
          team_count,
          team_size,
          description,
          bullet_points_array,
          programs_array,
          background_image,
          additional,
          created_at,
          updated_at
        FROM old_sport_infos
      SQL

      ActiveRecord::Base.connection.reset_pk_sequence!('sport_infos')

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
          WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_sport_infos';
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
            REFERENCES "#{r[:foreign_table_schema]}"."sport_infos" (#{r[:foreign_column_name]})
            ON DELETE RESTRICT
        SQL
      end

      drop_table :old_sport_infos

      Sport.all.each do |sport|
        begin
          returning =
            Team.
              where(sport: sport).
              uniq_column_values(:returning_date).
              pluck(:returning_date).
              map {|v| v.strftime("%A, %B %d, %Y") }.
              join(" and ")
          sport&.info&.update!(returning_dates: returning)
        rescue
          puts sport, Team.
            where(sport: sport).
            uniq_column_values(:returning_date).
            pluck(:returning_date).
            map {|v| v.strftime("%A, %B %d, %Y") }.
            join(" and ")
          raise
        end
      end
    end
  end
end
