class AuditTriggerV4 < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DROP TABLE IF EXISTS #{BetterRecord.db_audit_schema}.old_old_logged_actions CASCADE;
      DROP TABLE IF EXISTS #{BetterRecord.db_audit_schema}.old_logged_actions CASCADE;
      DROP SEQUENCE IF EXISTS #{BetterRecord.db_audit_schema}.old_old_logged_actions_event_id_seq;
      DROP SEQUENCE IF EXISTS #{BetterRecord.db_audit_schema}.old_logged_actions_event_id_seq;
    SQL

    children = execute <<-SQL
      SELECT pg_inherits.*, c.relname AS child, p.relname AS parent
      FROM
      pg_inherits JOIN pg_class AS c ON (inhrelid=c.oid)
      JOIN pg_class as p ON (inhparent=p.oid)
      WHERE p.relnamespace::regnamespace::text = '#{BetterRecord.db_audit_schema}';
    SQL

    children.each do |child|
      execute <<-SQL
        ALTER TABLE #{BetterRecord.db_audit_schema}.#{child['child']}
        RENAME TO #{'old_' * child['parent'].split('old_').size}#{child['child']}
      SQL
    end

    # seq = execute <<-SQL
    #   SELECT table_name, column_name, column_default from
    #   information_schema.columns where table_name='old_old_logged_actions' AND column_name = 'event_id';
    # SQL
    #
    # seq = seq.first
    #
    # val = "nextval('#{BetterRecord.db_audit_schema}.logged_actions_event_id_seq1'::regclass)"

    rows = execute <<-SQL
        SELECT trg.tgname,
            CASE trg.tgtype::integer & 66
                WHEN 2 THEN 'BEFORE'
                WHEN 64 THEN 'INSTEAD OF'
                ELSE 'AFTER'
            END AS trigger_type,
            CASE trg.tgtype::integer & cast(28 as int2)
                WHEN 16 THEN 'UPDATE'
                WHEN 8 THEN 'DELETE'
                WHEN 4 THEN 'INSERT'
                WHEN 20 THEN 'INSERT, UPDATE'
                WHEN 28 THEN 'INSERT, UPDATE, DELETE'
                WHEN 24 THEN 'UPDATE, DELETE'
                WHEN 12 THEN 'INSERT, DELETE'
            END AS trigger_event,
            tbl.relname AS table_name,
            tbl.relnamespace::regnamespace AS schema_name,
            obj_description(trg.oid) AS remarks,
            CASE
                WHEN trg.tgenabled='O' THEN 'ENABLED'
                ELSE 'DISABLED'
            END AS status,
            CASE trg.tgtype::integer & 1
                WHEN 1 THEN 'ROW'::text
                ELSE 'STATEMENT'::text
            END AS trigger_level
        FROM pg_trigger trg
            JOIN pg_class tbl on trg.tgrelid = tbl.oid
            JOIN pg_namespace ns ON ns.oid = tbl.relnamespace
        WHERE trg.tgname not like 'RI_ConstraintTrigger%'
            AND trg.tgname not like 'pg_sync_pg%'
    SQL

    rows.each do |r|
      if r['tgname'].to_s =~ /audit_trigger/
        execute "DROP TRIGGER IF EXISTS #{r['tgname']} ON #{r['schema_name']}.#{r['table_name']} CASCADE;"
      end
    end


    execute <<-SQL
      ALTER SEQUENCE IF EXISTS #{BetterRecord.db_audit_schema}.logged_actions_event_id_seq RENAME TO old_logged_actions_event_id_seq;
      ALTER TABLE #{BetterRecord.db_audit_schema}.logged_actions RENAME TO old_logged_actions
    SQL

    sql = ""
    source = File.new(BetterRecord::Engine.root.join('db', 'postgres-audit-v4-table.psql'), "r")
    while (line = source.gets)
      sql << line.gsub(/SELECTED_SCHEMA_NAME/, BetterRecord.db_audit_schema)
    end
    source.close

    execute sql

    sql = ""
    source = File.new(BetterRecord::Engine.root.join('db', 'postgres-audit-v4-trigger.psql'), "r")
    while (line = source.gets)
      sql << line.gsub(/SELECTED_SCHEMA_NAME/, BetterRecord.db_audit_schema)
    end
    source.close

    execute sql

    puts ''

    rows.each do |r|
      if r['tgname'].to_s =~ /audit_trigger/
        puts <<-TEXT
          PLEASE RECREATE ALL AUDIT TRIGGERS FOR #{r['table_name']}
          #{r}

        TEXT
      end
    end

    puts "\n\nTo insert old audits back into logged_actions run:\n\n"

    puts <<-RUBY
      INSERT INTO #{BetterRecord.db_audit_schema}.logged_actions_view
      (
        schema_name,
        table_name,
        full_name,
        relid,
        session_user_name,
        app_user_id,
        app_user_type,
        app_ip_address,
        action_tstamp_tx,
        action_tstamp_stm,
        action_tstamp_clk,
        transaction_id,
        application_name,
        client_addr,
        client_port,
        client_query,
        action,
        row_id,
        row_data,
        changed_fields,
        statement_only
      )
      SELECT
        schema_name,
        table_name,
        schema_name || '.' || table_name,
        relid,
        session_user_name,
        app_user_id,
        app_user_type,
        app_ip_address,
        action_tstamp_tx,
        action_tstamp_stm,
        action_tstamp_clk,
        transaction_id,
        application_name,
        client_addr,
        client_port,
        client_query,
        action,
        row_id,
        row_data,
        changed_fields,
        statement_only
      FROM #{BetterRecord.db_audit_schema}.old_logged_actions
      ORDER BY old_logged_actions.event_id;
    RUBY
  end
end
