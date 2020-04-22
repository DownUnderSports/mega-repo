# This migration comes from better_record (originally 20180518042050)
class CreateBetterRecordDBFunctions < ActiveRecord::Migration[5.2]
  def up
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm;"
    execute "CREATE EXTENSION IF NOT EXISTS btree_gin;"
    execute "CREATE EXTENSION IF NOT EXISTS pgcrypto;"

    sql = ""
    source = File.new(BetterRecord::Engine.root.join('db', 'postgres-audit-trigger.psql'), "r")
    while (line = source.gets)
      sql << line.gsub(/SELECTED_SCHEMA_NAME/, BetterRecord.db_audit_schema)
    end
    source.close

    execute sql

    execute <<-SQL
      CREATE or REPLACE FUNCTION public.temp_table_exists( varchar)
      RETURNS pg_catalog.bool AS
      $$
        BEGIN
          /* check the table exist in database and is visible*/
          PERFORM n.nspname, c.relname
          FROM pg_catalog.pg_class c
          LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
          WHERE n.nspname LIKE 'pg_temp_%' AND pg_catalog.pg_table_is_visible(c.oid)
          AND relname = $1;

          IF FOUND THEN
            RETURN TRUE;
          ELSE
            RETURN FALSE;
          END IF;

        END;
      $$
      LANGUAGE 'plpgsql' VOLATILE
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION hash_password(password text)
        RETURNS text AS
      $BODY$
      BEGIN
        password = crypt(password, gen_salt('bf', 8));

        RETURN password;
      END;
      $BODY$

      LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION validate_email(email text)
        RETURNS text AS
      $BODY$
      BEGIN
        IF email IS NOT NULL THEN
          IF email !~* '\\A[^@\\s;./[\\]\\\\]+(\\.[^@\\s;./[\\]\\\\]+)*@[^@\\s;./[\\]\\\\]+(\\.[^@\\s;./[\\]\\\\]+)*\\.[^@\\s;./[\\]\\\\]+\\Z' THEN
            RAISE EXCEPTION 'Invalid E-mail format %', email
                USING HINT = 'Please check your E-mail format.';
          END IF ;
          email = lower(email);
        END IF ;

        RETURN email;
      END;
      $BODY$
      LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION valid_email_trigger()
        RETURNS TRIGGER AS
      $BODY$
      BEGIN
        NEW.email = validate_email(NEW.email);

        RETURN NEW;
      END;
      $BODY$
      LANGUAGE plpgsql;
    SQL

    execute <<-SQL
      CREATE OR REPLACE FUNCTION unique_random_string(table_name text, column_name text, string_length integer default 6, prefix text default '')
      RETURNS text AS
      $BODY$
        DECLARE
          key TEXT;
          qry TEXT;
          found TEXT;
          letter TEXT;
          iterator INTEGER;
        BEGIN

          qry := 'SELECT ' || column_name || ' FROM ' || table_name || ' WHERE ' || column_name || '=';

          LOOP

            key := prefix;
            iterator := 0;

            WHILE iterator < string_length
            LOOP

              SELECT c INTO letter
              FROM regexp_split_to_table(
                'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
                ''
              ) c
              ORDER BY random()
              LIMIT 1;

              key := key || letter;

              iterator := iterator + 1;
            END LOOP;

            EXECUTE qry || quote_literal(key) INTO found;

            IF found IS NULL THEN
              EXIT;
            END IF;

          END LOOP;

          RETURN key;
        END;
      $BODY$
      LANGUAGE plpgsql;
    SQL

  end

  def down
    execute 'DROP FUNCTION IF EXISTS unique_random_string();'
    execute 'DROP FUNCTION IF EXISTS valid_email_trigger();'
    execute 'DROP FUNCTION IF EXISTS validate_email();'
    execute 'DROP FUNCTION IF EXISTS temp_table_exists();'
    execute "DROP FUNCTION IF EXISTS hash_password();"
    execute "DROP SCHEMA IF EXISTS #{BetterRecord.db_audit_schema} CASCADE;"
  end
end
