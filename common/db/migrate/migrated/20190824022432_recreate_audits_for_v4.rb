class RecreateAuditsForV4 < ActiveRecord::Migration[5.2]
  def up
    needs_data_insert = ActiveRecord::Base.connection.execute <<-SQL
      SELECT EXISTS (
        SELECT 1
        FROM   pg_catalog.pg_class c
        JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        WHERE  c.relname = 'old_logged_actions'
        AND    c.relkind = 'r'
      )
    SQL

    # if needs_data_insert.first['exists']
    #   execute <<-SQL
    #     INSERT INTO #{BetterRecord.db_audit_schema}.logged_actions_view
    #     (
    #       schema_name,
    #       table_name,
    #       full_name,
    #       relid,
    #       session_user_name,
    #       app_user_id,
    #       app_user_type,
    #       app_ip_address,
    #       action_tstamp_tx,
    #       action_tstamp_stm,
    #       action_tstamp_clk,
    #       transaction_id,
    #       application_name,
    #       client_addr,
    #       client_port,
    #       client_query,
    #       action,
    #       row_id,
    #       row_data,
    #       changed_fields,
    #       statement_only
    #     )
    #     SELECT
    #       schema_name,
    #       table_name,
    #       schema_name || '.' || table_name,
    #       relid,
    #       session_user_name,
    #       app_user_id,
    #       app_user_type,
    #       app_ip_address,
    #       action_tstamp_tx,
    #       action_tstamp_stm,
    #       action_tstamp_clk,
    #       transaction_id,
    #       application_name,
    #       client_addr,
    #       client_port,
    #       client_query,
    #       action,
    #       row_id,
    #       row_data,
    #       changed_fields,
    #       statement_only
    #     FROM #{BetterRecord.db_audit_schema}.old_logged_actions
    #     ORDER BY old_logged_actions.event_id;
    #   SQL

      execute <<-SQL
        DROP TABLE IF EXISTS auditing.old_logged_actions CASCADE;
        TRUNCATE TABLE auditing.logged_actions* CASCADE
      SQL
    # end

    foreign_keys = (
      execute <<-SQL
        SELECT
          conname,
          pg_catalog.pg_get_constraintdef(r.oid, true) as condef,
          c.relname,
          c.relnamespace::regnamespace
        FROM pg_catalog.pg_constraint r
        INNER JOIN pg_catalog.pg_class c
          ON c.oid = r.conrelid
        WHERE r.contype = 'f' ORDER BY 1;
      SQL
    ).to_a

    foreign_keys.each do |fk|
      execute <<-SQL
        ALTER TABLE #{fk['relnamespace']}.#{fk['relname']} DROP CONSTRAINT "#{fk['conname']}"
      SQL
    end

    %w[
      active_storage_attachments
      active_storage_blobs
      addresses
      athletes
      athletes_sports
      coaches
      competing_teams_travelers
      event_results
      event_result_static_files
      flight_airports
      flight_legs
      flight_schedules
      flight_tickets
      meeting_registrations
      meeting_video_views
      meeting_videos
      meetings
      officials
      payment_items
      payment_remittances
      payments
      schools
      shirt_order_items
      shirt_order_shipments
      shirt_orders
      sources
      sports
      staff_assignments
      staffs
      states
      student_lists
      traveler_base_debits
      traveler_buses
      traveler_buses_travelers
      traveler_credits
      traveler_debits
      traveler_hotels
      traveler_offers
      traveler_rooms
      travelers
      user_ambassadors
      user_event_registrations
      user_marathon_registrations
      user_overrides
      user_relations
      user_uniform_orders
    ].each do |tbl|
      execute "DROP TRIGGER IF EXISTS audit_trigger_row ON #{tbl};"
      execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON #{tbl};"

      audit_table tbl

      execute <<-SQL
        WITH deleted AS (
          DELETE FROM ONLY "#{tbl}"
          RETURNING *
        )
        INSERT INTO "#{tbl}"
        SELECT * FROM deleted;
      SQL
    end

    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON users;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON users;"
    audit_table :users, true, false, %w[ password register_secret certificate updated_at ]

    execute <<-SQL
      WITH deleted AS (
        DELETE FROM users
        RETURNING *
      )
      INSERT INTO users
      SELECT * FROM deleted;
    SQL

    execute <<-SQL
      DELETE FROM auditing.logged_actions WHERE action = 'D'
    SQL

    foreign_keys.each do |fk|
      execute <<-SQL
        ALTER TABLE #{fk['relnamespace']}.#{fk['relname']}
        ADD CONSTRAINT "#{fk['conname']}"
        #{fk['condef']}
      SQL
    end
  end
end
