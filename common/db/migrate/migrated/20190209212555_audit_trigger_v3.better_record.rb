# This migration comes from better_record (originally 20190209195134)
class AuditTriggerV3 < ActiveRecord::Migration[5.2]
  def up


    children = execute <<-SQL
      SELECT pg_inherits.*, c.relname AS child, p.relname AS parent
      FROM
      pg_inherits JOIN pg_class AS c ON (inhrelid=c.oid)
      JOIN pg_class as p ON (inhparent=p.oid);
    SQL

    children.each do |child|
      execute <<-SQL
        ALTER TABLE #{BetterRecord.db_audit_schema}.#{child['child']}
        RENAME TO #{'old_' * child['parent'].split('old_').size}#{child['child']}
      SQL
    end

    execute <<-SQL
      ALTER SEQUENCE IF EXISTS auditing.old_logged_actions_event_id_seq RENAME TO old_old_logged_actions_event_id_seq;
      ALTER TABLE #{BetterRecord.db_audit_schema}.old_logged_actions
      RENAME TO old_old_logged_actions
    SQL

    # seq = execute <<-SQL
    #   SELECT table_name, column_name, column_default from
    #   information_schema.columns where table_name='old_old_logged_actions' AND column_name = 'event_id';
    # SQL
    #
    # seq = seq.first
    #
    # val = "nextval('auditing.logged_actions_event_id_seq1'::regclass)"


    execute <<-SQL
      ALTER SEQUENCE IF EXISTS auditing.logged_actions_event_id_seq RENAME TO old_logged_actions_event_id_seq;
      ALTER TABLE #{BetterRecord.db_audit_schema}.logged_actions
      RENAME TO old_logged_actions
    SQL

    sql = ""
    source = File.new(BetterRecord::Engine.root.join('db', 'postgres-audit-v3-table.psql'), "r")
    while (line = source.gets)
      sql << line.gsub(/SELECTED_SCHEMA_NAME/, BetterRecord.db_audit_schema)
    end
    source.close

    execute sql

    sql = ""
    source = File.new(BetterRecord::Engine.root.join('db', 'postgres-audit-v3-trigger.psql'), "r")
    while (line = source.gets)
      sql << line.gsub(/SELECTED_SCHEMA_NAME/, BetterRecord.db_audit_schema)
    end
    source.close

    execute sql

    rows = execute <<-SQL
      select trg.tgname,
          CASE trg.tgtype::integer & 66
              WHEN 2 THEN 'BEFORE'
              WHEN 64 THEN 'INSTEAD OF'
              ELSE 'AFTER'
          end as trigger_type,
         case trg.tgtype::integer & cast(28 as int2)
           when 16 then 'UPDATE'
           when 8 then 'DELETE'
           when 4 then 'INSERT'
           when 20 then 'INSERT, UPDATE'
           when 28 then 'INSERT, UPDATE, DELETE'
           when 24 then 'UPDATE, DELETE'
           when 12 then 'INSERT, DELETE'
         end as trigger_event,
         tbl.relname as table_name,
         obj_description(trg.oid) as remarks,
           case
            when trg.tgenabled='O' then 'ENABLED'
              else 'DISABLED'
          end as status,
          case trg.tgtype::integer & 1
            when 1 then 'ROW'::text
            else 'STATEMENT'::text
          end as trigger_level
      FROM pg_trigger trg
        JOIN pg_class tbl on trg.tgrelid = tbl.oid
        JOIN pg_namespace ns ON ns.oid = tbl.relnamespace
      WHERE trg.tgname not like 'RI_ConstraintTrigger%'
        AND trg.tgname not like 'pg_sync_pg%'
    SQL

    rows.each do |r|
      if r['tgname'].to_s =~ /audit_trigger/
        puts "\n\nPLEASE RECREATE ALL AUDIT TRIGGERS FOR #{r['table_name']}\n\n#{r}\n\n"
      end
    end

    puts "\n\nTo insert old audits back into logged_actions run:\n\n"

    puts <<-RUBY
      INSERT INTO #{BetterRecord.db_audit_schema}.logged_actions_view
      (
        schema_name,
        table_name,
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

      INSERT INTO #{BetterRecord.db_audit_schema}.logged_actions_view
      (
        schema_name,
        table_name,
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
      FROM #{BetterRecord.db_audit_schema}.old_old_logged_actions
      ORDER BY old_old_logged_actions.event_id;
    RUBY
  end
end
