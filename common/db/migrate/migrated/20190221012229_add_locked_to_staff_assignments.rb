class AddLockedToStaffAssignments < ActiveRecord::Migration[5.2]
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
      WHERE idx.indrelid::regclass::text = 'staff_assignments';
    SQL

    #===== MIGRATION ===
    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON staff_assignments;"

    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON staff_assignments;"

    execute "DROP INDEX IF EXISTS index_staff_assignments_on_reason;"

    execute "DROP INDEX IF EXISTS index_staff_assignments_on_assigned_by_id;"

    execute "DROP INDEX IF EXISTS index_staff_assignments_on_assigned_to_id;"

    execute "DROP INDEX IF EXISTS index_staff_assignments_on_user_id;"

    rename_table :staff_assignments, :old_staff_assignments

    create_table :staff_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :assigned_to, null: false, foreign_key: { to_table: :users }
      t.references :assigned_by, null: false, foreign_key: { to_table: :users }

      t.text :reason, default: -> { "'Follow Up'" }

      t.boolean :completed, null: false, default: false
      t.boolean :unneeded, null: false, default: false
      t.boolean :reviewed, null: false, default: false
      t.boolean :locked, null: false, default: false

      t.datetime :completed_at
      t.datetime :unneeded_at
      t.datetime :reviewed_at

      t.date :follow_up_date

      t.index [ :reason ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :staff_assignments

    execute <<-SQL
      INSERT INTO staff_assignments
      (
        id,
        user_id,
        assigned_to_id,
        assigned_by_id,
        reason,
        completed,
        unneeded,
        reviewed,
        completed_at,
        unneeded_at,
        reviewed_at,
        follow_up_date,
        created_at,
        updated_at
      )
      SELECT
        id,
        user_id,
        assigned_to_id,
        assigned_by_id,
        reason,
        completed,
        unneeded,
        reviewed,
        completed_at,
        unneeded_at,
        reviewed_at,
        follow_up_date,
        created_at,
        updated_at
      FROM old_staff_assignments
    SQL

    ActiveRecord::Base.connection.reset_pk_sequence!('staff_assignments')

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
        WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_staff_assignments';

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
          REFERENCES "#{r[:foreign_table_schema]}"."staff_assignments" (#{r[:foreign_column_name]})
          ON DELETE RESTRICT
      SQL
    end

    drop_table :old_staff_assignments
  end
end
