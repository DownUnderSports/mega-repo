class AddTrackDatesToFlightAirports < ActiveRecord::Migration[5.2]
  def up
    unless Flight::Airport.column_names.include? 'track_departing_date'
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
        WHERE idx.indrelid::regclass::text = 'flight_airports';
      SQL

      #===== MIGRATION ===

      execute "DROP TRIGGER audit_trigger_row ON flight_airports;"

      execute "DROP TRIGGER audit_trigger_stm ON flight_airports;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_address_id;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_code;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_name;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_carrier;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_dst;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_preferred;"

      execute "DROP INDEX IF EXISTS index_flight_airports_on_selectable;"

      rename_table :flight_airports, :old_flight_airports

      create_table :flight_airports do |t|
        t.text :code,    null: false
        t.text :name,    null: false
        t.text :carrier, null: false, default: 'qantas'

        t.money_integer :cost

        t.text :location_override
        t.references :address,    foreign_key: true
        t.integer    :tz_offset,  null: false, default: 0
        t.boolean    :dst,        null: false, default: true

        t.boolean :preferred,  null: false, default: false
        t.boolean :selectable, null: false, default: true

        t.date :track_departing_date
        t.date :track_returning_date

        t.index [ :code ],       unique: true
        t.index [ :name ],       unique: false
        t.index [ :carrier ],    unique: false
        t.index [ :dst ],        unique: false
        t.index [ :preferred ],  unique: false
        t.index [ :selectable ], unique: false

        t.timestamps default: -> { 'NOW()' }
      end

      execute <<-SQL
        INSERT INTO flight_airports
        (
          id,
          code,
          name,
          carrier,
          cost,
          location_override,
          address_id,
          tz_offset,
          dst,
          preferred,
          selectable,
          created_at,
          updated_at
        )
        SELECT
          id,
          code,
          name,
          carrier,
          cost,
          location_override,
          address_id,
          tz_offset,
          dst,
          preferred,
          selectable,
          created_at,
          updated_at
        FROM old_flight_airports
      SQL

      ActiveRecord::Base.connection.reset_pk_sequence!('flight_airports')

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
          WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_flight_airports';

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
            REFERENCES "#{r[:foreign_table_schema]}"."flight_airports" (#{r[:foreign_column_name]})
            ON DELETE RESTRICT
        SQL
      end

      audit_table :flight_airports
      drop_table :old_flight_airports

      departing = '2020-07-04'.to_date
      returning = '2020-07-13'.to_date

      Team::TRACK_DATES.each do |code, add|
        begin
          airport = Flight::Airport.find_by!(code: code)
          airport.update!(track_departing_date: departing + add.to_i, track_returning_date: returning + add.to_i)
        rescue
          puts code
          raise
        end
      end
    end
  end
end
