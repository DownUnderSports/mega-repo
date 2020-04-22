class RebuildUserTravelPreparations < ActiveRecord::Migration[5.2]
  def up
    set_db_year "public"
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
      WHERE idx.indrelid::regclass::text = 'user_travel_preparations';
    SQL

    #===== MIGRATION ===
    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON public.user_travel_preparations;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON public.user_travel_preparations;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON year_2019.user_travel_preparations;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON year_2019.user_travel_preparations;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON year_2020.user_travel_preparations;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON year_2020.user_travel_preparations;"

    execute "ALTER TABLE year_2020.user_travel_preparations DROP CONSTRAINT year_2020_user_travel_preparations_pkey;"
    execute "ALTER TABLE year_2019.user_travel_preparations DROP CONSTRAINT year_2019_user_travel_preparations_pkey;"
    execute "ALTER TABLE public.user_travel_preparations DROP CONSTRAINT user_travel_preparations_pkey;"

    %w[
      year_2019
      year_2020
      public
    ].each do |year|
      set_db_year year

      execute "DROP INDEX IF EXISTS year_2020_user_travel_preparations_pkey;"
      execute "DROP INDEX IF EXISTS year_2019_user_travel_preparations_pkey;"
      execute "DROP INDEX IF EXISTS user_travel_preparations_pkey;"
      execute "DROP INDEX IF EXISTS index_user_travel_preparations_on_user_id;"
      execute "ALTER TABLE #{year}.user_travel_preparations RENAME TO old_travel_preparations"
    end

    set_db_year "public"

    create_table :user_travel_preparations do |t|
      t.integer :user_id, null: false

      t.index [ :user_id ]

      t.jsonb :applications, null: false, default: {}
      t.jsonb :confirmations, null: false, default: {}
      t.jsonb :followups, null: false, default: {}
      t.jsonb :items_received, null: false, default: {}

      t.date :eta_email_date
      t.date :visa_message_sent_date

      t.boolean :extra_eta_processing, null: false, default: false

      t.three_state :has_multiple_citizenships, null: false, default: 'U'
      t.text :citizenships_array, null: false, array: true, default: []

      t.three_state :has_aliases, null: false, default: 'U'
      t.string :aliases_array, null: false, array: true, default: []

      t.three_state :has_convictions, null: false, default: 'U'
      t.text :convictions_array, null: false, array: true, default: []


      t.timestamps default: -> { 'NOW()' }
    end

    set_table_to_yearly \
      table_name: :user_travel_preparations,
      foreign_keys: [
        {
          from_col: :user_id,
          to_table: :users,
          to_schema: :public
        }
      ]

    BetterRecord::LoggedAction.where(table_name: :user_travel_preparations).delete_all

    audit_yearly_table :user_travel_preparations

    %w[
      year_2019
      year_2020
    ].each do |year|
      execute <<-SQL
        INSERT INTO #{year}.user_travel_preparations
        (
          id,
          user_id,
          followups,
          confirmations,
          items_received,
          applications,
          eta_email_date,
          visa_message_sent_date,
          extra_eta_processing,
          has_multiple_citizenships,
          citizenships_array,
          has_aliases,
          aliases_array,
          has_convictions,
          convictions_array,
          created_at,
          updated_at
        )
        SELECT
          id,
          user_id,
          ('{ "joined_team":"' || COALESCE(joined_team_followup_date::text, '') || '", "domestic":"' || COALESCE(domestic_followup_date::text, '') || '", "insurance":"' || COALESCE(insurance_followup_date::text, '') || '", "insurance":"' || COALESCE(insurance_followup_date::text, '') || '" }')::JSONB,
          ('{ "address":"' || COALESCE(address_confirmed_date::text, '') || '", "dob":"' || COALESCE(dob_confirmed_date::text, '') || '", "name":"" }')::JSONB,
          ('{ "fundraising_packet":"' || COALESCE(fundraising_packet_received_date::text, '') || '", "travel_packet":"' || COALESCE(travel_packet_received_date::text, '') || '" }')::JSONB,
          ('{ "passport":"' || COALESCE(applied_for_passport_date::text, '') || '", "eta":"' || COALESCE(applied_for_eta_date::text, '') || '" }')::JSONB,
          eta_email_date,
          visa_message_sent_date,
          extra_eta_processing,
          has_multiple_citizenships,
          citizenships_array,
          has_aliases,
          aliases_array,
          has_convictions,
          convictions_array,
          created_at,
          updated_at
        FROM #{year}.old_travel_preparations
      SQL
    end

    ActiveRecord::Base.connection.reset_pk_sequence!('user_travel_preparations')

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
        WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_travel_preparations';

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
          REFERENCES "#{r[:foreign_table_schema]}"."user_travel_preparations" (#{r[:foreign_column_name]})
          ON DELETE RESTRICT
      SQL
    end

    drop_table :old_travel_preparations, force: :cascade
  end
end
