class AddIsNumberedToSports < ActiveRecord::Migration[5.2]
  def up
    unless Sport.column_names.include? 'is_numbered'
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
        WHERE idx.indrelid::regclass::text = 'sports';
      SQL

      #===== MIGRATION ===
      execute "DROP TRIGGER IF EXISTS audit_trigger_row ON sports;"

      execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON sports;"

      execute "DROP INDEX IF EXISTS index_sports_on_abbr;"

      execute "DROP INDEX IF EXISTS index_sports_on_abbr_gender;"

      execute "DROP INDEX IF EXISTS index_sports_on_full;"

      execute "DROP INDEX IF EXISTS index_sports_on_full_gender;"

      rename_table :sports, :old_sports

      create_table :sports do |t|
        t.text :abbr, null: false
        t.text :full, null: false
        t.text :abbr_gender, null: false
        t.text :full_gender, null: false

        t.boolean :is_numbered, null: false, default: false

        t.index [ :abbr ], unique: false
        t.index [ :full ], unique: false
        t.index [ :abbr_gender ], unique: true
        t.index [ :full_gender ], unique: true
      end

      execute <<-SQL
        INSERT INTO sports
        (
          id,
          abbr,
          "full",
          abbr_gender,
          full_gender
        )
        SELECT
          id,
          abbr,
          "full",
          abbr_gender,
          full_gender
        FROM old_sports
      SQL

      ActiveRecord::Base.connection.reset_pk_sequence!('sports')

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
          WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_sports';

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
            REFERENCES "#{r[:foreign_table_schema]}"."sports" (#{r[:foreign_column_name]})
            ON DELETE RESTRICT
        SQL
      end

      drop_table :old_sports

      audit_table :sports

      Sport.all.each {|sp| sp.update(is_numbered: true) if sp.abbr =~ /B$/}
    end
  end
end
