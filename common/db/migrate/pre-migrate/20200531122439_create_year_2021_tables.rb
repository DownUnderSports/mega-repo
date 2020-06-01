class CreateYear2021Tables < ActiveRecord::Migration[5.2]
  def up
    rows = execute <<-SQL
      SELECT
        'ALTER TABLE ' || quote_ident(ns.nspname) || '.' || quote_ident(tb.relname) ||
        ' ALTER CONSTRAINT ' || quote_ident(conname) ||
        ' DEFERRABLE INITIALLY DEFERRED;'
        AS query_text
      FROM pg_constraint c
             JOIN pg_class tb ON tb.oid = c.conrelid
             JOIN pg_namespace ns ON ns.oid = tb.relnamespace
      WHERE ns.nspname IN ('public') AND c.contype = 'f';
    SQL

    rows.each {|r| execute r['query_text'] }

    execute <<-SQL
      CREATE SCHEMA IF NOT EXISTS "year_2021";
      SET CONSTRAINTS ALL DEFERRED;
    SQL

    tables = %w[
      competing_teams
      competing_teams_travelers
      flight_legs
      flight_tickets
      flight_schedules
      mailings
      meeting_registrations
      meeting_video_views
      payments
      payment_join_terms
      payment_items
      payment_remittances
      sent_mails
      staff_assignments
      staff_assignment_visits
      student_lists
      teams
      traveler_buses
      traveler_buses_travelers
      traveler_credits
      traveler_debits
      traveler_offers
      traveler_requests
      traveler_rooms
      travelers
      user_event_registrations
      user_marathon_registrations
      user_messages
      user_overrides
      user_transfer_expectations
      user_travel_preparations
      user_uniform_orders
    ]

    table_datas = tables.map do |table_name|
      table_id = (
        execute <<-SQL
          SELECT c.oid,
            n.nspname,
            c.relname
          FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = '#{table_name}'
            AND n.nspname = 'year_2020'
          ORDER BY 2, 3;
        SQL
      ).first

      public_id = (
        execute <<-SQL
          SELECT c.oid,
            n.nspname,
            c.relname
          FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE c.relname = '#{table_name}'
            AND n.nspname = 'public'
          ORDER BY 2, 3;
        SQL
      ).first

      # {
      #       "oid" => 13454289,
      #   "nspname" => "public",
      #   "relname" => "travelers"
      # }

      table_info = (
        execute <<-SQL
          SELECT
            c.relchecks,
            c.relkind,
            c.relhasindex,
            c.relhasrules,
            c.relhastriggers,
            c.relrowsecurity,
            c.relforcerowsecurity,
            pg_catalog.array_to_string(c.reloptions || array(select 'toast.' || x from pg_catalog.unnest(tc.reloptions) x), ', '),
            c.reltablespace,
            CASE WHEN c.reloftype = 0 THEN '' ELSE c.reloftype::pg_catalog.regtype::pg_catalog.text END,
            c.relpersistence,
            c.relreplident
          FROM pg_catalog.pg_class c
            LEFT JOIN pg_catalog.pg_class tc ON (c.reltoastrelid = tc.oid)
          WHERE c.oid = '#{public_id['oid']}'
        SQL
      ).first

      # {
      #             "relchecks" => 0,
      #               "relkind" => "r",
      #           "relhasindex" => true,
      #           "relhasrules" => false,
      #        "relhastriggers" => true,
      #        "relrowsecurity" => false,
      #   "relforcerowsecurity" => false,
      #       "array_to_string" => "autovacuum_vacuum_threshold=50, autovacuum_vacuum_scale_factor=0.2",
      #         "reltablespace" => 0,
      #             "reloftype" => "",
      #        "relpersistence" => "p",
      #          "relreplident" => "d"
      # }

      table_columns = (
        execute <<-SQL
          SELECT
            a.attname,
            pg_catalog.format_type(a.atttypid, a.atttypmod),
            (
              SELECT substring(pg_catalog.pg_get_expr(d.adbin, d.adrelid) for 128)
              FROM pg_catalog.pg_attrdef d
              WHERE d.adrelid = a.attrelid AND d.adnum = a.attnum AND a.atthasdef
            ) AS DEFAULT,
            a.attnotnull,
            (
              SELECT
                c.collname FROM pg_catalog.pg_collation c,
                pg_catalog.pg_type t
              WHERE
                c.oid = a.attcollation
                AND
                t.oid = a.atttypid
                AND
                a.attcollation <> t.typcollation
            ) AS attcollation,
            a.attidentity,
            a.attstorage,
            CASE WHEN a.attstattarget=-1 THEN NULL ELSE a.attstattarget END AS attstattarget,
            pg_catalog.col_description(a.attrelid, a.attnum)
          FROM pg_catalog.pg_attribute a
          WHERE a.attrelid = '#{public_id['oid']}' AND a.attnum > 0 AND NOT a.attisdropped
          ORDER BY a.attnum;
        SQL
      ).to_a

      # [
      #   {
      #             "attname" => "id",
      #         "format_type" => "bigint",
      #             "default" => "nextval('travelers_id_seq'::regclass)",
      #          "attnotnull" => true,
      #        "attcollation" => nil,
      #         "attidentity" => "",
      #          "attstorage" => "p",
      #       "attstattarget" => nil,
      #     "col_description" => nil
      #   },
      #   ...
      # ]

      table_indexes = (
        execute <<-SQL
          SELECT
            c2.relname,
            i.indisprimary,
            i.indisunique,
            i.indisclustered,
            i.indisvalid,
            pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
            pg_catalog.pg_get_constraintdef(con.oid, true),
            contype,
            condeferrable,
            condeferred,
            i.indisreplident,
            c2.reltablespace
          FROM
            pg_catalog.pg_class c,
            pg_catalog.pg_class c2,
            pg_catalog.pg_index i
          LEFT JOIN
            pg_catalog.pg_constraint con
            ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
          WHERE c.oid = '#{table_id['oid']}' AND c.oid = i.indrelid AND i.indexrelid = c2.oid
          ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname;
        SQL
      ).to_a

      # [
      #   {
      #                  "relname" => "travelers_pkey",
      #             "indisprimary" => true,
      #              "indisunique" => true,
      #           "indisclustered" => false,
      #               "indisvalid" => true,
      #          "pg_get_indexdef" => "CREATE UNIQUE INDEX travelers_pkey ON travelers USING btree (id)",
      #     "pg_get_constraintdef" => "PRIMARY KEY (id)",
      #                  "contype" => "p",
      #            "condeferrable" => false,
      #              "condeferred" => false,
      #           "indisreplident" => false,
      #            "reltablespace" => 0
      #   }
      #   ...
      # ]

      constraint = ""

      table_indexes.dup.each do |idx|
        if idx['pg_get_constraintdef'].present? && idx['contype'] == 'p'
          constraint = ",\nCONSTRAINT year_YEAR_#{table_name}_pkey #{idx['pg_get_constraintdef']}"
          table_indexes.delete_at(table_indexes.index(idx))
        end
      end

      foreign_keys = (
        execute <<-SQL
          SELECT
            conname,
            pg_catalog.pg_get_constraintdef(r.oid, true) as condef
          FROM pg_catalog.pg_constraint r
          WHERE r.conrelid = '#{table_id['oid']}' AND r.contype = 'f' ORDER BY 1;
        SQL
      ).to_a

      # [
      #   {
      #     "conname" => "fk_rails_d584eeb41e",
      #      "condef" => "FOREIGN KEY (team_id) REFERENCES teams(id)"
      #   }
      #   ...
      # ]

      {
        constraint:    constraint,
        foreign_keys:  foreign_keys,
        table_columns: table_columns,
        table_id:      table_id,
        table_indexes: table_indexes,
        table_info:    table_info,
        table_name:    table_name,
      }
    end

    table_datas.each do |info|
      execute <<-SQL
        CREATE TABLE IF NOT EXISTS "year_2021"."#{info[:table_name]}" (
          operating_year INTEGER DEFAULT 2021 CHECK (operating_year = 2021)#{info[:constraint].sub('year_YEAR', "year_2021")}
        ) INHERITS ("public"."#{info[:table_name]}");
      SQL
    end

    table_datas.each do |info|
      table_name = info[:table_name]
      constraint = info[:constraint]

      audit_table %Q("year_2021"."#{table_name}")

      info[:foreign_keys].each do |fk|
        str, from_col, to_table, to_col, ext = *fk["condef"].match(/^FOREIGN\s*KEY\s*\((.*?)\)\s*REFERENCES\s*(\S+)\((.*?)\)\s*(.*)$/)

        to_table = to_table.split('.')
        to_schema = "public"
        if to_table[1].present?
          to_schema, to_table = to_table
        else
          to_table = to_table[0]
        end

        if to_table.in? tables
          to_schema = "year_2021"
        end

        identifier = Digest::SHA256.hexdigest("2021_#{table_name}_#{from_col}").first(10)

        execute <<-SQL
          ALTER TABLE "year_2021"."#{table_name}"
          ADD CONSTRAINT fk_rails_#{identifier}
          FOREIGN KEY (#{from_col})
          REFERENCES #{to_schema}.#{to_table}(#{to_col}) #{ext}
        SQL
      end
      info[:table_indexes].each do |idx|
        execute idx["pg_get_indexdef"].sub(/ON\s+(year_2020\.)?#{table_name}/, "ON year_2021.#{table_name}")
      end
    end
  end

  def down
    execute "DROP SCHEMA IF EXISTS year_2021 CASCADE"
  end
end
