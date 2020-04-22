class AddManagementToStaffs < ActiveRecord::Migration[5.2]
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
      WHERE idx.indrelid::regclass::text = 'staffs';
    SQL

    #===== MIGRATION ===
    execute "DROP TRIGGER audit_trigger_row ON staffs;"

    execute "DROP TRIGGER audit_trigger_stm ON staffs;"

    rename_table :staffs, :old_staffs

    create_table :staffs do |t|
      t.boolean :admin, null: false, default: false
      t.boolean :trusted, null: false, default: false
      t.boolean :management, null: false, default: false
      t.boolean :australia, null: false, default: false
      t.boolean :credits, null: false, default: false
      t.boolean :debits, null: false, default: false
      t.boolean :finances, null: false, default: false
      t.boolean :flights, null: false, default: false
      t.boolean :importing, null: false, default: false
      t.boolean :inventories, null: false, default: false
      t.boolean :meetings, null: false, default: false
      t.boolean :offers, null: false, default: false
      t.boolean :passports, null: false, default: false
      t.boolean :photos, null: false, default: false
      t.boolean :recaps, null: false, default: false
      t.boolean :remittances, null: false, default: false
      t.boolean :schools, null: false, default: false
      t.boolean :uniforms, null: false, default: false

      t.timestamps default: -> { 'NOW()' }
    end

    execute <<-SQL
      INSERT INTO staffs
      (
        id,
        admin,
        trusted,
        australia,
        credits,
        debits,
        finances,
        flights,
        importing,
        inventories,
        meetings,
        offers,
        passports,
        photos,
        recaps,
        remittances,
        schools,
        uniforms,
        created_at,
        updated_at
      )
      SELECT
        id,
        admin,
        trusted,
        australia,
        credits,
        debits,
        finances,
        flights,
        importing,
        inventories,
        meetings,
        offers,
        passports,
        photos,
        recaps,
        remittances,
        schools,
        uniforms,
        created_at,
        updated_at
      FROM old_staffs
    SQL

    ActiveRecord::Base.connection.reset_pk_sequence!('staffs')

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
        WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_staffs';

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
          REFERENCES "#{r[:foreign_table_schema]}"."staffs" (#{r[:foreign_column_name]})
          ON DELETE RESTRICT
      SQL
    end

    drop_table :old_staffs

    audit_table :staffs
  end
end
