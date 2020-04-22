class MoveOfficialsTeamReference < ActiveRecord::Migration[5.2]
  def up
    unless Official.column_names.include? 'sport_id'
      require 'db/views'

      Views.destroy_all(self)

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
        WHERE idx.indrelid::regclass::text = 'officials';
      SQL

      #===== MIGRATION ===

      execute "DROP TRIGGER audit_trigger_row ON officials;"

      execute "DROP TRIGGER audit_trigger_stm ON officials;"

      execute "DROP INDEX IF EXISTS index_officials_on_team_id;"

      execute <<-SQL
        DELETE FROM auditing.logged_actions WHERE table_name = 'officials'
      SQL

      rename_table :officials, :old_officials

      create_table :officials do |t|
        t.references :sport, null: false, foreign_key: true
        t.references :state, null: false, foreign_key: true
        t.text :category, default: -> { "'official'::text" }

        t.timestamps default: -> { 'NOW()' }
      end

      audit_table :officials

      execute <<-SQL
        INSERT INTO officials
        (
          id,
          sport_id,
          state_id,
          category,
          created_at,
          updated_at
        )
        SELECT
          old_officials.id,
          teams.sport_id,
          teams.state_id,
          category,
          old_officials.created_at,
          old_officials.updated_at
        FROM old_officials
        INNER JOIN teams
          ON teams.id = old_officials.team_id
      SQL

      ActiveRecord::Base.connection.reset_pk_sequence!('officials')

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
          WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_officials';

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
            REFERENCES "#{r[:foreign_table_schema]}"."officials" (#{r[:foreign_column_name]})
            ON DELETE RESTRICT
        SQL
      end

      drop_table :old_officials
    end
  end
end
