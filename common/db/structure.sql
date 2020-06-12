SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: auditing; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auditing;


--
-- Name: SCHEMA auditing; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA auditing IS 'Out-of-table audit/history logging tables and trigger functions';


--
-- Name: year_2019; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA year_2019;


--
-- Name: year_2020; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA year_2020;


--
-- Name: btree_gin; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS btree_gin WITH SCHEMA public;


--
-- Name: EXTENSION btree_gin; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION btree_gin IS 'support for indexing common datatypes in GIN';


--
-- Name: hstore; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS hstore WITH SCHEMA public;


--
-- Name: EXTENSION hstore; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION hstore IS 'data type for storing sets of (key, value) pairs';


--
-- Name: pg_stat_statements; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA public;


--
-- Name: EXTENSION pg_stat_statements; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_stat_statements IS 'track execution statistics of all SQL statements executed';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: difficulty_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.difficulty_level AS ENUM (
    'extreme',
    'hard',
    'moderate',
    'easy',
    'none'
);


--
-- Name: exchange_rate_integer; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.exchange_rate_integer AS bigint NOT NULL DEFAULT 0;


--
-- Name: gender; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.gender AS ENUM (
    'F',
    'M',
    'U'
);


--
-- Name: meeting_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.meeting_category AS ENUM (
    'I',
    'D',
    'S',
    'A',
    'P',
    'F'
);


--
-- Name: money_integer; Type: DOMAIN; Schema: public; Owner: -
--

CREATE DOMAIN public.money_integer AS integer NOT NULL DEFAULT 0;


--
-- Name: temp_table_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.temp_table_info AS (
	schema_name text,
	table_name text
);


--
-- Name: three_state; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.three_state AS ENUM (
    'Y',
    'N',
    'U'
);


--
-- Name: transfer_contact_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transfer_contact_status AS ENUM (
    'evaluated',
    'contacted',
    'confirmed',
    'completed'
);


--
-- Name: transferability; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.transferability AS ENUM (
    'always',
    'necessary',
    'none'
);


--
-- Name: traveler_request_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.traveler_request_category AS ENUM (
    'flight',
    'medical',
    'diet',
    'room',
    'arrival',
    'departure',
    'other'
);


--
-- Name: unsubscriber_category; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.unsubscriber_category AS ENUM (
    'C',
    'E',
    'M',
    'T'
);


--
-- Name: audit_table(regclass); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.audit_table(target_table regclass) RETURNS void
    LANGUAGE sql
    AS $_$
  SELECT auditing.audit_table($1, BOOLEAN 't', BOOLEAN 't');
$_$;


--
-- Name: FUNCTION audit_table(target_table regclass); Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON FUNCTION auditing.audit_table(target_table regclass) IS '
  Add auditing support to the given table. Row-level changes will be logged with full client query text. No cols are ignored.
';


--
-- Name: audit_table(regclass, boolean, boolean); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean) RETURNS void
    LANGUAGE sql
    AS $_$
  SELECT auditing.audit_table($1, $2, $3, ARRAY[]::text[]);
$_$;


--
-- Name: audit_table(regclass, boolean, boolean, text[]); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
  DECLARE
    stm_targets text = 'INSERT OR UPDATE OR DELETE OR TRUNCATE';
    table_info temp_table_info;
    _full_name regclass;
    _q_txt text;
    _pk_column_name text;
    _pk_column_snip text;
    _ignored_cols_snip text = '';
  BEGIN
    table_info = auditing.get_table_information(target_table);
    _full_name = quote_ident(table_info.schema_name) || '.' || quote_ident(table_info.table_name);

    EXECUTE 'DROP TRIGGER IF EXISTS audit_trigger_row ON ' || _full_name;
    EXECUTE 'DROP TRIGGER IF EXISTS audit_trigger_stm ON ' || _full_name;


    EXECUTE 'CREATE TABLE IF NOT EXISTS auditing.logged_actions_' || quote_ident(table_info.table_name) || '(
      CHECK (table_name = ' || quote_literal(table_info.table_name) || '),
      LIKE auditing.logged_actions INCLUDING ALL
    ) INHERITS (auditing.logged_actions)';

    IF audit_rows THEN
      _pk_column_name = auditing.get_primary_key_column(_full_name::TEXT);

      IF _pk_column_name IS NOT NULL THEN
        _pk_column_snip = ', ' || quote_literal(_pk_column_name);
      ELSE
        _pk_column_snip = ', NULL';
      END IF;

      IF array_length(ignored_cols,1) > 0 THEN
        _ignored_cols_snip = ', ' || quote_literal(ignored_cols);
      END IF;
      _q_txt = 'CREATE TRIGGER audit_trigger_row AFTER INSERT OR UPDATE OR DELETE ON ' ||
          _full_name ||
          ' FOR EACH ROW EXECUTE PROCEDURE auditing.if_modified_func(' ||
          quote_literal(audit_query_text) || _pk_column_snip || _ignored_cols_snip || ');';
      RAISE NOTICE '%',_q_txt;
      EXECUTE _q_txt;
      stm_targets = 'TRUNCATE';
    ELSE
    END IF;

    _q_txt = '' ||
        'CREATE TRIGGER audit_trigger_stm AFTER ' || stm_targets ||
        ' ON ' || _full_name ||
        ' FOR EACH STATEMENT EXECUTE PROCEDURE ' ||
        'auditing.if_modified_func(' || quote_literal(audit_query_text) || ');';
    RAISE NOTICE '%',_q_txt;
    EXECUTE _q_txt;

  END;
$$;


--
-- Name: FUNCTION audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]); Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON FUNCTION auditing.audit_table(target_table regclass, audit_rows boolean, audit_query_text boolean, ignored_cols text[]) IS '
  Add auditing support to a table.

  Arguments:
      target_table:   Table name, schema qualified if not on search_path
      audit_rows:     Record each row change, or only audit at a statement level
      audit_query_text: Record the text of the client query that triggered the audit event?
      ignored_cols:   Columns to exclude from update diffs, ignore updates that change only ignored cols.
';


--
-- Name: get_primary_key_column(text); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.get_primary_key_column(target_table text) RETURNS text
    LANGUAGE plpgsql
    AS $$
  DECLARE
    _pk_query_text text;
    _pk_column_name text;
  BEGIN
    _pk_query_text =  'SELECT a.attname ' ||
                      'FROM   pg_index i ' ||
                      'JOIN   pg_attribute a ON a.attrelid = i.indrelid ' ||
                      '                    AND a.attnum = ANY(i.indkey) ' ||
                      'WHERE  i.indrelid = ' || quote_literal(target_table::TEXT) || '::regclass ' ||
                      'AND    i.indisprimary ' ||
                      'AND format_type(a.atttypid, a.atttypmod) = ' || quote_literal('bigint'::TEXT) ||
                      'LIMIT 1';

    EXECUTE _pk_query_text INTO _pk_column_name;
    return _pk_column_name;
  END;
$$;


--
-- Name: FUNCTION get_primary_key_column(target_table text); Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON FUNCTION auditing.get_primary_key_column(target_table text) IS '
  Get primary key column name if single PK and type bigint.

  Arguments:
      target_table:   Table name, schema qualified if not on search_path
';


--
-- Name: get_table_information(regclass); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.get_table_information(target_table regclass) RETURNS public.temp_table_info
    LANGUAGE plpgsql
    AS $$
  DECLARE
    table_row record;
    info_row temp_table_info;
  BEGIN

    FOR table_row IN SELECT * FROM pg_catalog.pg_class WHERE oid = target_table LOOP
      info_row.schema_name = table_row.relnamespace::regnamespace::TEXT;
      info_row.table_name = table_row.relname::TEXT;
    END LOOP;
    return info_row;
  END;
$$;


--
-- Name: FUNCTION get_table_information(target_table regclass); Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON FUNCTION auditing.get_table_information(target_table regclass) IS '
  Get unqualified table name and schema name from a table regclass.

  Arguments:
      target_table: Table name, schema qualified if not on search_path
';


--
-- Name: if_modified_func(); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.if_modified_func() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $_$
  DECLARE
    audit_row auditing.logged_actions;
    include_values boolean;
    log_diffs boolean;
    h_old hstore;
    h_new hstore;
    user_row record;
    excluded_cols text[] = ARRAY[]::text[];
    pk_val_query text;
  BEGIN
    IF TG_WHEN <> 'AFTER' THEN
      RAISE EXCEPTION 'auditing.if_modified_func() may only run as an AFTER trigger';
    END IF;

    audit_row = ROW(
      nextval('auditing.logged_actions_event_id_seq'), -- event_id
      TG_TABLE_SCHEMA::text,                                       -- schema_name
      TG_TABLE_NAME::text,                                         -- table_name
      TG_TABLE_SCHEMA::text || '.' || TG_TABLE_NAME::text,         -- full_name
      TG_RELID,                                                    -- relation OID for much quicker searches
      session_user::text,                                          -- session_user_name
      NULL, NULL, NULL,                                            -- app_user_id, app_user_type, app_ip_address
      current_timestamp,                                           -- action_tstamp_tx
      statement_timestamp(),                                       -- action_tstamp_stm
      clock_timestamp(),                                           -- action_tstamp_clk
      txid_current(),                                              -- transaction ID
      current_setting('application_name'),                         -- client application
      inet_client_addr(),                                          -- client_addr
      inet_client_port(),                                          -- client_port
      current_query(),                                             -- top-level query or queries (if multistatement) from client
      substring(TG_OP,1,1),                                        -- action
      NULL, NULL, NULL,                                            -- row_id, row_data, changed_fields
      'f'                                                          -- statement_only
    );

    IF NOT TG_ARGV[0]::boolean IS DISTINCT FROM 'f'::boolean THEN
      audit_row.client_query = NULL;
    END IF;

    IF ((TG_LEVEL = 'ROW') AND (TG_ARGV[1] IS NOT NULL) AND (TG_ARGV[1]::TEXT <> 'NULL') AND (TG_ARGV[1]::TEXT <> 'null') AND (TG_ARGV[1]::TEXT <> '')) THEN
      pk_val_query = 'SELECT $1.' || quote_ident(TG_ARGV[1]::text);

      IF (TG_OP IS DISTINCT FROM 'DELETE') THEN
        EXECUTE pk_val_query INTO audit_row.row_id USING NEW;
      END IF;

      IF audit_row.row_id IS NULL THEN
        EXECUTE pk_val_query INTO audit_row.row_id USING OLD;
      END IF;
    END IF;

    IF TG_ARGV[2] IS NOT NULL THEN
      excluded_cols = TG_ARGV[2]::text[];
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS
      "_app_user" (user_id integer, user_type text, ip_address inet);

    IF (TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW') THEN
      audit_row.row_data = hstore(OLD.*) - excluded_cols;
      audit_row.changed_fields =  (hstore(NEW.*) - audit_row.row_data) - excluded_cols;
      IF audit_row.changed_fields = hstore('') THEN
        -- All changed fields are ignored. Skip this update.
        RETURN NULL;
      END IF;
    ELSIF (TG_OP = 'DELETE' AND TG_LEVEL = 'ROW') THEN
      audit_row.row_data = hstore(OLD.*) - excluded_cols;
    ELSIF (TG_OP = 'INSERT' AND TG_LEVEL = 'ROW') THEN
      audit_row.row_data = hstore(NEW.*) - excluded_cols;
    ELSIF (TG_LEVEL = 'STATEMENT' AND TG_OP IN ('INSERT','UPDATE','DELETE','TRUNCATE')) THEN
      audit_row.statement_only = 't';
    ELSE
      RAISE EXCEPTION '[auditing.if_modified_func] - Trigger func added as trigger for unhandled case: %, %',TG_OP, TG_LEVEL;
      RETURN NULL;
    END IF;

    -- inject app_user data into audit
    BEGIN
      PERFORM
      n.nspname, c.relname
      FROM
      pg_catalog.pg_class c
      LEFT JOIN
      pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
      WHERE
      n.nspname like 'pg_temp_%'
      AND
      c.relname = '_app_user';

      IF FOUND THEN
      FOR user_row IN SELECT * FROM _app_user LIMIT 1 LOOP
        audit_row.app_user_id = user_row.user_id;
        audit_row.app_user_type = user_row.user_type;
        audit_row.app_ip_address = user_row.ip_address;
      END LOOP;
      END IF;
    END;
    -- end app_user data

    INSERT INTO auditing.logged_actions_view VALUES (audit_row.*);
    RETURN NULL;
  END;
$_$;


--
-- Name: FUNCTION if_modified_func(); Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON FUNCTION auditing.if_modified_func() IS '
  Track changes to a table at the statement and/or row level.

  Optional parameters to trigger in CREATE TRIGGER call:

  param 0: boolean, whether to log the query text. Default ''t''.

  param 1: text, primary_key_column of audited table if bigint.

  param 2: text[], columns to ignore in updates. Default [].

       Updates to ignored cols are omitted from changed_fields.

       Updates with only ignored cols changed are not inserted
       into the audit log.

       Almost all the processing work is still done for updates
       that ignored. If you need to save the load, you need to use
       WHEN clause on the trigger instead.

       No warning or error is issued if ignored_cols contains columns
       that do not exist in the target table. This lets you specify
       a standard set of ignored columns.

  There is no parameter to disable logging of values. Add this trigger as
  a ''FOR EACH STATEMENT'' rather than ''FOR EACH ROW'' trigger if you do not
  want to log row values.

  Note that the user name logged is the login role for the session. The audit trigger
  cannot obtain the active role because it is reset by the SECURITY DEFINER invocation
  of the audit trigger its self.
';


--
-- Name: logged_actions_partition(); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.logged_actions_partition() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $_$
  DECLARE
    table_name text;
    table_info temp_table_info;
  BEGIN
    table_info = auditing.get_table_information(NEW.table_name::regclass);

    table_name = table_info.table_name::TEXT;

    EXECUTE 'CREATE TABLE IF NOT EXISTS auditing.logged_actions_' || quote_ident(table_name) || '(
      CHECK (table_name = ' || quote_literal(table_info.table_name) || '),
      LIKE auditing.logged_actions INCLUDING ALL
    ) INHERITS (auditing.logged_actions)';

    EXECUTE 'INSERT INTO auditing.logged_actions_' || quote_ident(table_name) || ' VALUES ($1.*)' USING NEW;

    RETURN NEW;
  END;
$_$;


--
-- Name: skip_logged_actions_main(); Type: FUNCTION; Schema: auditing; Owner: -
--

CREATE FUNCTION auditing.skip_logged_actions_main() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
  BEGIN
    raise exception 'insert on wrong table';
    RETURN NULL;
  END;
$$;


--
-- Name: bad_insert_on_parent_table(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.bad_insert_on_parent_table() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog', 'public'
    AS $$
        BEGIN
          RAISE EXCEPTION 'Insert on Base Table: %', TG_TABLE_NAME::regclass::text;
          RETURN NULL;
        END;
      $$;


--
-- Name: create_inverse_relationship_type(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_inverse_relationship_type(text, text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
            BEGIN
              IF NOT EXISTS ( SELECT * FROM user_relationship_types WHERE ( inverse = $1 )) THEN
                INSERT INTO user_relationship_types (value, inverse)
                VALUES ( $2, $1 );
              END IF;
            END;
          $_$;


--
-- Name: hash_password(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.hash_password(password text) RETURNS text
    LANGUAGE plpgsql
    AS $$
      BEGIN
        password = crypt(password, gen_salt('bf', 8));

        RETURN password;
      END;
      $$;


--
-- Name: relationship_type_insert(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.relationship_type_insert() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
          BEGIN
            PERFORM create_inverse_relationship_type(NEW.value, NEW.inverse);

            RETURN NEW;
          END;
          $$;


--
-- Name: relationship_type_update(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.relationship_type_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $_$
          BEGIN
            IF EXISTS ( SELECT * FROM user_relationship_types WHERE ( inverse =  OLD.value) ) THEN
              DELETE FROM user_relationship_types WHERE ( inverse = $3 );
            END IF;

            PERFORM create_inverse_relationship_type(NEW.value, NEW.inverse);

            RETURN NEW;
          END;
          $_$;


--
-- Name: temp_table_exists(character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.temp_table_exists(character varying) RETURNS boolean
    LANGUAGE plpgsql
    AS $_$
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
      $_$;


--
-- Name: unique_random_string(text, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unique_random_string(table_name text, column_name text, string_length integer DEFAULT 6, prefix text DEFAULT ''::text) RETURNS text
    LANGUAGE plpgsql
    AS $$
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
      $$;


--
-- Name: user_changed(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.user_changed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
            BEGIN
                              IF (NEW.password IS NOT NULL)
                AND (
                  (TG_OP = 'INSERT') OR ( NEW.password IS DISTINCT FROM OLD.password )
                ) THEN
                  IF (NEW.password IS DISTINCT FROM 'CLEAR_EXISTING_PASSWORD_FOR_ROW') THEN
                    NEW.password = hash_password(NEW.password);
                  ELSE
                    NEW.password = NULL;
                  END IF;
                ELSE
                  IF (TG_OP IS DISTINCT FROM 'INSERT') THEN
                    NEW.password = OLD.password;
                  ELSE
                    NEW.password = NULL;
                  END IF;
                END IF;


                IF (NEW.certificate IS NOT NULL)
                AND (
                  (TG_OP = 'INSERT') OR ( NEW.certificate IS DISTINCT FROM OLD.certificate )
                ) THEN
                  IF (NEW.certificate IS DISTINCT FROM 'CLEAR_EXISTING_PASSWORD_FOR_ROW') THEN
                    NEW.certificate = hash_password(NEW.certificate);
                  ELSE
                    NEW.certificate = NULL;
                  END IF;
                ELSE
                  IF (TG_OP IS DISTINCT FROM 'INSERT') THEN
                    NEW.certificate = OLD.certificate;
                  ELSE
                    NEW.certificate = NULL;
                  END IF;
                END IF;


                            IF (TG_OP = 'INSERT') OR ( NEW.email IS DISTINCT FROM OLD.email ) THEN
                NEW.email = validate_email(NEW.email);
              END IF;


              RETURN NEW;
            END;
            $$;


--
-- Name: valid_email_trigger(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.valid_email_trigger() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
      BEGIN
        NEW.email = validate_email(NEW.email);

        RETURN NEW;
      END;
      $$;


--
-- Name: validate_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.validate_email(email text) RETURNS text
    LANGUAGE plpgsql
    AS $$
      BEGIN
        IF email IS NOT NULL THEN
          IF email !~* '\A[^@\s;./[\]\\]+(\.[^@\s;./[\]\\]+)*@[^@\s;./[\]\\]+(\.[^@\s;./[\]\\]+)*\.[^@\s;./[\]\\]+\Z' THEN
            RAISE EXCEPTION 'Invalid E-mail format %', email
                USING HINT = 'Please check your E-mail format.';
          END IF ;
          email = lower(email);
        END IF ;

        RETURN email;
      END;
      $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: logged_actions; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions (
    event_id bigint NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    full_name text NOT NULL,
    relid oid NOT NULL,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone NOT NULL,
    action_tstamp_stm timestamp with time zone NOT NULL,
    action_tstamp_clk timestamp with time zone NOT NULL,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text NOT NULL,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean NOT NULL,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text])))
);


--
-- Name: TABLE logged_actions; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON TABLE auditing.logged_actions IS 'History of auditable actions on audited tables, from auditing.if_modified_func()';


--
-- Name: COLUMN logged_actions.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_event_id_seq; Type: SEQUENCE; Schema: auditing; Owner: -
--

CREATE SEQUENCE auditing.logged_actions_event_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: logged_actions_event_id_seq; Type: SEQUENCE OWNED BY; Schema: auditing; Owner: -
--

ALTER SEQUENCE auditing.logged_actions_event_id_seq OWNED BY auditing.logged_actions.event_id;


--
-- Name: logged_actions_active_storage_attachments; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_active_storage_attachments (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_active_storage_attachments_table_name_check CHECK ((table_name = 'active_storage_attachments'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_active_storage_attachments.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_active_storage_attachments.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_active_storage_attachments.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_active_storage_attachments.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_active_storage_attachments.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_active_storage_attachments.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_active_storage_attachments.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_active_storage_attachments.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_active_storage_attachments.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_active_storage_attachments.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_active_storage_attachments.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_active_storage_attachments.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_active_storage_attachments.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_active_storage_attachments.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_active_storage_attachments.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_active_storage_attachments.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_attachments.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_active_storage_blobs; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_active_storage_blobs (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_active_storage_blobs_table_name_check CHECK ((table_name = 'active_storage_blobs'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_active_storage_blobs.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_active_storage_blobs.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_active_storage_blobs.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_active_storage_blobs.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_active_storage_blobs.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_active_storage_blobs.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_active_storage_blobs.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_active_storage_blobs.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_active_storage_blobs.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_active_storage_blobs.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_active_storage_blobs.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_active_storage_blobs.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_active_storage_blobs.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_active_storage_blobs.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_active_storage_blobs.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_active_storage_blobs.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_active_storage_blobs.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_addresses; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_addresses (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_addresses_table_name_check CHECK ((table_name = 'addresses'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_addresses.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_addresses.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_addresses.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_addresses.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_addresses.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_addresses.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_addresses.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_addresses.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_addresses.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_addresses.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_addresses.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_addresses.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_addresses.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_addresses.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_addresses.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_addresses.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_addresses.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_addresses.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_addresses.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_addresses.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_addresses.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_addresses.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_addresses.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_athletes; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_athletes (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_athletes_table_name_check CHECK ((table_name = 'athletes'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_athletes.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_athletes.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_athletes.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_athletes.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_athletes.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_athletes.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_athletes.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_athletes.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_athletes.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_athletes.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_athletes.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_athletes.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_athletes.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_athletes.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_athletes.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_athletes.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_athletes.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_athletes.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_athletes.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_athletes.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_athletes.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_athletes.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_athletes_sports; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_athletes_sports (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_athletes_sports_table_name_check CHECK ((table_name = 'athletes_sports'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_athletes_sports.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_athletes_sports.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_athletes_sports.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_athletes_sports.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_athletes_sports.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_athletes_sports.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_athletes_sports.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_athletes_sports.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_athletes_sports.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_athletes_sports.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_athletes_sports.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_athletes_sports.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_athletes_sports.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_athletes_sports.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_athletes_sports.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_athletes_sports.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_athletes_sports.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_athletes_sports.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_athletes_sports.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_athletes_sports.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_athletes_sports.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_athletes_sports.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_athletes_sports.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_coaches; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_coaches (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_coaches_table_name_check CHECK ((table_name = 'coaches'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_coaches.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_coaches.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_coaches.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_coaches.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_coaches.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_coaches.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_coaches.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_coaches.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_coaches.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_coaches.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_coaches.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_coaches.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_coaches.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_coaches.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_coaches.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_coaches.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_coaches.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_coaches.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_coaches.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_coaches.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_coaches.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_coaches.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_coaches.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_competing_teams; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_competing_teams (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_competing_teams_table_name_check CHECK ((table_name = 'competing_teams'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_competing_teams.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_competing_teams.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_competing_teams.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_competing_teams.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_competing_teams.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_competing_teams.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_competing_teams.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_competing_teams.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_competing_teams.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_competing_teams.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_competing_teams.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_competing_teams.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_competing_teams.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_competing_teams.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_competing_teams.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_competing_teams.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_competing_teams.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_competing_teams.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_competing_teams.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_competing_teams.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_competing_teams.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_competing_teams.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_competing_teams_travelers; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_competing_teams_travelers (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_competing_teams_travelers_table_name_check CHECK ((table_name = 'competing_teams_travelers'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_competing_teams_travelers.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_competing_teams_travelers.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_competing_teams_travelers.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_event_result_static_files; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_event_result_static_files (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_event_result_static_files_table_name_check CHECK ((table_name = 'event_result_static_files'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_event_result_static_files.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_event_result_static_files.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_event_result_static_files.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_event_result_static_files.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_event_result_static_files.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_event_result_static_files.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_event_result_static_files.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_event_result_static_files.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_event_result_static_files.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_event_result_static_files.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_event_result_static_files.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_event_result_static_files.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_event_result_static_files.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_event_result_static_files.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_event_result_static_files.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_event_result_static_files.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_event_result_static_files.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_event_result_static_files.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_event_result_static_files.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_event_result_static_files.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_event_result_static_files.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_event_result_static_files.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_result_static_files.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_event_results; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_event_results (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_event_results_table_name_check CHECK ((table_name = 'event_results'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_event_results.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_event_results.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_event_results.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_event_results.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_event_results.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_event_results.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_event_results.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_event_results.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_event_results.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_event_results.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_event_results.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_event_results.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_event_results.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_event_results.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_event_results.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_event_results.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_event_results.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_event_results.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_event_results.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_event_results.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_event_results.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_event_results.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_event_results.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_flight_airports; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_flight_airports (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_flight_airports_table_name_check CHECK ((table_name = 'flight_airports'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_flight_airports.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_flight_airports.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_flight_airports.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_airports.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_airports.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_flight_airports.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_airports.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_flight_airports.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_flight_airports.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_airports.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_airports.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_airports.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_flight_airports.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_flight_airports.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_flight_airports.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_flight_airports.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_flight_airports.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_flight_airports.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_flight_airports.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_flight_airports.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_flight_airports.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_flight_airports.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_airports.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_flight_legs; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_flight_legs (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_flight_legs_table_name_check CHECK ((table_name = 'flight_legs'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_flight_legs.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_flight_legs.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_flight_legs.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_legs.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_legs.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_flight_legs.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_legs.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_flight_legs.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_flight_legs.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_legs.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_legs.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_legs.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_flight_legs.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_flight_legs.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_flight_legs.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_flight_legs.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_flight_legs.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_flight_legs.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_flight_legs.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_flight_legs.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_flight_legs.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_flight_legs.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_legs.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_flight_schedules; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_flight_schedules (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_flight_schedules_table_name_check CHECK ((table_name = 'flight_schedules'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_flight_schedules.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_flight_schedules.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_flight_schedules.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_schedules.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_schedules.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_flight_schedules.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_schedules.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_flight_schedules.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_flight_schedules.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_schedules.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_schedules.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_schedules.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_flight_schedules.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_flight_schedules.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_flight_schedules.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_flight_schedules.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_flight_schedules.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_flight_schedules.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_flight_schedules.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_flight_schedules.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_flight_schedules.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_flight_schedules.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_schedules.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_flight_tickets; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_flight_tickets (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_flight_tickets_table_name_check CHECK ((table_name = 'flight_tickets'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_flight_tickets.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_flight_tickets.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_flight_tickets.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_tickets.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_flight_tickets.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_flight_tickets.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_tickets.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_flight_tickets.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_flight_tickets.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_flight_tickets.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_tickets.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_flight_tickets.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_flight_tickets.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_flight_tickets.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_flight_tickets.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_flight_tickets.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_flight_tickets.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_flight_tickets.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_flight_tickets.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_flight_tickets.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_flight_tickets.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_flight_tickets.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_flight_tickets.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_mailings; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_mailings (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_mailings_table_name_check CHECK ((table_name = 'mailings'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_mailings.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_mailings.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_mailings.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_mailings.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_mailings.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_mailings.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_mailings.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_mailings.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_mailings.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_mailings.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_mailings.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_mailings.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_mailings.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_mailings.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_mailings.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_mailings.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_mailings.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_mailings.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_mailings.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_mailings.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_mailings.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_mailings.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_mailings.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_meeting_registrations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_meeting_registrations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_meeting_registrations_table_name_check CHECK ((table_name = 'meeting_registrations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_meeting_registrations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_meeting_registrations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_meeting_registrations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_registrations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_registrations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_meeting_registrations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_registrations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_meeting_registrations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_meeting_registrations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_registrations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_registrations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_registrations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_meeting_registrations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_meeting_registrations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_meeting_registrations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_meeting_registrations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_meeting_registrations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_meeting_registrations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_meeting_registrations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_meeting_registrations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_meeting_registrations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_meeting_registrations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_registrations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_meeting_video_views; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_meeting_video_views (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_meeting_video_views_table_name_check CHECK ((table_name = 'meeting_video_views'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_meeting_video_views.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_meeting_video_views.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_meeting_video_views.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_video_views.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_video_views.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_meeting_video_views.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_video_views.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_meeting_video_views.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_meeting_video_views.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_video_views.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_video_views.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_video_views.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_meeting_video_views.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_meeting_video_views.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_meeting_video_views.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_meeting_video_views.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_meeting_video_views.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_meeting_video_views.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_meeting_video_views.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_meeting_video_views.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_meeting_video_views.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_meeting_video_views.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_video_views.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_meeting_videos; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_meeting_videos (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_meeting_videos_table_name_check CHECK ((table_name = 'meeting_videos'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_meeting_videos.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_meeting_videos.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_meeting_videos.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_videos.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meeting_videos.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_meeting_videos.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_videos.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_meeting_videos.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_meeting_videos.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meeting_videos.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_videos.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meeting_videos.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_meeting_videos.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_meeting_videos.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_meeting_videos.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_meeting_videos.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_meeting_videos.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_meeting_videos.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_meeting_videos.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_meeting_videos.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_meeting_videos.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_meeting_videos.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meeting_videos.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_meetings; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_meetings (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_meetings_table_name_check CHECK ((table_name = 'meetings'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_meetings.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_meetings.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_meetings.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meetings.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_meetings.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_meetings.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meetings.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_meetings.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_meetings.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_meetings.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meetings.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_meetings.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_meetings.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_meetings.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_meetings.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_meetings.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_meetings.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_meetings.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_meetings.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_meetings.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_meetings.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_meetings.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_meetings.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_officials; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_officials (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_officials_table_name_check CHECK ((table_name = 'officials'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_officials.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_officials.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_officials.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_officials.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_officials.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_officials.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_officials.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_officials.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_officials.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_officials.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_officials.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_officials.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_officials.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_officials.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_officials.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_officials.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_officials.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_officials.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_officials.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_officials.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_officials.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_officials.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_officials.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_payment_items; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_payment_items (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_payment_items_table_name_check CHECK ((table_name = 'payment_items'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_payment_items.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_payment_items.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_payment_items.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payment_items.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payment_items.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_payment_items.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payment_items.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_payment_items.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_payment_items.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payment_items.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payment_items.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payment_items.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_payment_items.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_payment_items.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_payment_items.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_payment_items.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_payment_items.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_payment_items.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_payment_items.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_payment_items.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_payment_items.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_payment_items.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_items.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_payment_remittances; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_payment_remittances (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_payment_remittances_table_name_check CHECK ((table_name = 'payment_remittances'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_payment_remittances.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_payment_remittances.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_payment_remittances.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payment_remittances.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payment_remittances.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_payment_remittances.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payment_remittances.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_payment_remittances.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_payment_remittances.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payment_remittances.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payment_remittances.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payment_remittances.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_payment_remittances.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_payment_remittances.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_payment_remittances.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_payment_remittances.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_payment_remittances.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_payment_remittances.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_payment_remittances.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_payment_remittances.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_payment_remittances.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_payment_remittances.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payment_remittances.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_payments; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_payments (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_payments_table_name_check CHECK ((table_name = 'payments'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_payments.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_payments.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_payments.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payments.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_payments.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_payments.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payments.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_payments.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_payments.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_payments.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payments.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_payments.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_payments.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_payments.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_payments.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_payments.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_payments.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_payments.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_payments.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_payments.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_payments.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_payments.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_payments.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_schools; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_schools (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_schools_table_name_check CHECK ((table_name = 'schools'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_schools.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_schools.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_schools.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_schools.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_schools.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_schools.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_schools.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_schools.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_schools.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_schools.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_schools.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_schools.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_schools.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_schools.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_schools.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_schools.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_schools.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_schools.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_schools.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_schools.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_schools.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_schools.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_schools.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_sent_mails; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_sent_mails (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_sent_mails_table_name_check CHECK ((table_name = 'sent_mails'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_sent_mails.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_sent_mails.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_sent_mails.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sent_mails.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sent_mails.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_sent_mails.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sent_mails.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_sent_mails.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_sent_mails.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sent_mails.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sent_mails.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sent_mails.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_sent_mails.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_sent_mails.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_sent_mails.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_sent_mails.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_sent_mails.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_sent_mails.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_sent_mails.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_sent_mails.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_sent_mails.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_sent_mails.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sent_mails.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_shirt_order_items; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_shirt_order_items (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_shirt_order_items_table_name_check CHECK ((table_name = 'shirt_order_items'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_shirt_order_items.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_shirt_order_items.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_shirt_order_items.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_order_items.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_order_items.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_shirt_order_items.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_order_items.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_shirt_order_items.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_shirt_order_items.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_order_items.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_order_items.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_order_items.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_shirt_order_items.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_shirt_order_items.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_shirt_order_items.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_shirt_order_items.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_shirt_order_items.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_shirt_order_items.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_shirt_order_items.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_shirt_order_items.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_shirt_order_items.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_shirt_order_items.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_items.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_shirt_order_shipments; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_shirt_order_shipments (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_shirt_order_shipments_table_name_check CHECK ((table_name = 'shirt_order_shipments'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_shirt_order_shipments.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_shirt_order_shipments.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_order_shipments.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_shirt_orders; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_shirt_orders (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_shirt_orders_table_name_check CHECK ((table_name = 'shirt_orders'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_shirt_orders.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_shirt_orders.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_shirt_orders.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_orders.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_shirt_orders.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_shirt_orders.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_orders.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_shirt_orders.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_shirt_orders.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_shirt_orders.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_orders.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_shirt_orders.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_shirt_orders.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_shirt_orders.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_shirt_orders.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_shirt_orders.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_shirt_orders.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_shirt_orders.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_shirt_orders.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_shirt_orders.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_shirt_orders.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_shirt_orders.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_shirt_orders.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_sources; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_sources (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_sources_table_name_check CHECK ((table_name = 'sources'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_sources.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_sources.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_sources.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sources.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sources.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_sources.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sources.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_sources.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_sources.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sources.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sources.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sources.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_sources.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_sources.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_sources.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_sources.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_sources.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_sources.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_sources.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_sources.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_sources.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_sources.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sources.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_sports; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_sports (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_sports_table_name_check CHECK ((table_name = 'sports'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_sports.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_sports.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_sports.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sports.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_sports.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_sports.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sports.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_sports.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_sports.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_sports.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sports.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_sports.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_sports.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_sports.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_sports.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_sports.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_sports.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_sports.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_sports.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_sports.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_sports.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_sports.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_sports.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_staff_assignment_visits; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_staff_assignment_visits (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_staff_assignment_visits_table_name_check CHECK ((table_name = 'staff_assignment_visits'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_staff_assignment_visits.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_staff_assignment_visits.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignment_visits.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_staff_assignments; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_staff_assignments (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_staff_assignments_table_name_check CHECK ((table_name = 'staff_assignments'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_staff_assignments.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_staff_assignments.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_staff_assignments.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staff_assignments.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staff_assignments.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_staff_assignments.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staff_assignments.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_staff_assignments.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_staff_assignments.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staff_assignments.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staff_assignments.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staff_assignments.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_staff_assignments.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_staff_assignments.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_staff_assignments.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_staff_assignments.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_staff_assignments.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_staff_assignments.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_staff_assignments.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_staff_assignments.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_staff_assignments.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_staff_assignments.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staff_assignments.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_staffs; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_staffs (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_staffs_table_name_check CHECK ((table_name = 'staffs'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_staffs.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_staffs.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_staffs.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staffs.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_staffs.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_staffs.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staffs.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_staffs.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_staffs.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_staffs.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staffs.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_staffs.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_staffs.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_staffs.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_staffs.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_staffs.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_staffs.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_staffs.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_staffs.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_staffs.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_staffs.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_staffs.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_staffs.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_states; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_states (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_states_table_name_check CHECK ((table_name = 'states'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_states.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_states.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_states.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_states.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_states.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_states.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_states.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_states.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_states.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_states.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_states.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_states.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_states.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_states.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_states.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_states.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_states.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_states.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_states.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_states.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_states.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_states.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_states.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_student_lists; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_student_lists (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_student_lists_table_name_check CHECK ((table_name = 'student_lists'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_student_lists.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_student_lists.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_student_lists.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_student_lists.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_student_lists.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_student_lists.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_student_lists.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_student_lists.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_student_lists.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_student_lists.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_student_lists.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_student_lists.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_student_lists.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_student_lists.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_student_lists.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_student_lists.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_student_lists.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_student_lists.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_student_lists.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_student_lists.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_student_lists.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_student_lists.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_student_lists.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_teams; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_teams (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_teams_table_name_check CHECK ((table_name = 'teams'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_teams.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_teams.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_teams.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_teams.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_teams.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_teams.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_teams.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_teams.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_teams.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_teams.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_teams.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_teams.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_teams.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_teams.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_teams.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_teams.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_teams.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_teams.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_teams.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_teams.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_teams.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_teams.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_teams.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_base_debits; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_base_debits (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_base_debits_table_name_check CHECK ((table_name = 'traveler_base_debits'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_base_debits.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_base_debits.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_base_debits.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_base_debits.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_base_debits.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_base_debits.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_base_debits.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_base_debits.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_base_debits.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_base_debits.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_base_debits.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_base_debits.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_base_debits.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_base_debits.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_base_debits.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_base_debits.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_base_debits.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_buses; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_buses (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_buses_table_name_check CHECK ((table_name = 'traveler_buses'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_buses.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_buses.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_buses.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_buses.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_buses.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_buses.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_buses.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_buses.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_buses.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_buses.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_buses.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_buses.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_buses.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_buses.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_buses.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_buses.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_buses.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_buses.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_buses.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_buses.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_buses.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_buses.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_buses_travelers; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_buses_travelers (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_buses_travelers_table_name_check CHECK ((table_name = 'traveler_buses_travelers'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_buses_travelers.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_buses_travelers.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_credits; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_credits (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_credits_table_name_check CHECK ((table_name = 'traveler_credits'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_credits.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_credits.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_credits.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_credits.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_credits.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_credits.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_credits.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_credits.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_credits.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_credits.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_credits.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_credits.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_credits.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_credits.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_credits.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_credits.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_credits.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_credits.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_credits.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_credits.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_credits.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_credits.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_credits.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_debits; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_debits (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_debits_table_name_check CHECK ((table_name = 'traveler_debits'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_debits.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_debits.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_debits.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_debits.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_debits.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_debits.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_debits.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_debits.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_debits.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_debits.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_debits.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_debits.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_debits.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_debits.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_debits.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_debits.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_debits.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_debits.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_debits.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_debits.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_debits.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_debits.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_debits.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_hotels; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_hotels (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_hotels_table_name_check CHECK ((table_name = 'traveler_hotels'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_hotels.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_hotels.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_hotels.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_hotels.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_hotels.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_hotels.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_hotels.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_hotels.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_hotels.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_hotels.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_hotels.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_hotels.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_hotels.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_hotels.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_hotels.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_hotels.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_hotels.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_hotels.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_hotels.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_hotels.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_hotels.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_hotels.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_hotels.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_offers; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_offers (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_offers_table_name_check CHECK ((table_name = 'traveler_offers'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_offers.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_offers.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_offers.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_offers.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_offers.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_offers.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_offers.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_offers.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_offers.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_offers.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_offers.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_offers.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_offers.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_offers.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_offers.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_offers.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_offers.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_offers.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_offers.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_offers.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_offers.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_offers.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_offers.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_traveler_rooms; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_traveler_rooms (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_traveler_rooms_table_name_check CHECK ((table_name = 'traveler_rooms'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_traveler_rooms.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_traveler_rooms.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_traveler_rooms.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_rooms.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_traveler_rooms.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_traveler_rooms.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_rooms.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_traveler_rooms.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_traveler_rooms.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_traveler_rooms.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_rooms.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_traveler_rooms.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_traveler_rooms.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_traveler_rooms.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_traveler_rooms.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_traveler_rooms.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_traveler_rooms.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_traveler_rooms.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_traveler_rooms.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_traveler_rooms.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_traveler_rooms.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_traveler_rooms.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_traveler_rooms.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_travelers; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_travelers (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_travelers_table_name_check CHECK ((table_name = 'travelers'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_travelers.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_travelers.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_travelers.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_travelers.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_travelers.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_travelers.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_travelers.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_travelers.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_travelers.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_travelers.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_travelers.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_travelers.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_travelers.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_travelers.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_travelers.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_travelers.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_travelers.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_travelers.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_travelers.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_travelers.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_travelers.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_travelers.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_travelers.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_ambassadors; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_ambassadors (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_ambassadors_table_name_check CHECK ((table_name = 'user_ambassadors'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_ambassadors.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_ambassadors.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_ambassadors.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_ambassadors.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_ambassadors.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_ambassadors.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_ambassadors.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_ambassadors.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_ambassadors.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_ambassadors.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_ambassadors.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_ambassadors.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_ambassadors.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_ambassadors.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_ambassadors.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_ambassadors.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_ambassadors.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_ambassadors.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_ambassadors.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_ambassadors.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_ambassadors.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_ambassadors.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_ambassadors.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_event_registrations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_event_registrations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_event_registrations_table_name_check CHECK ((table_name = 'user_event_registrations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_event_registrations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_event_registrations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_event_registrations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_event_registrations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_event_registrations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_event_registrations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_event_registrations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_event_registrations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_event_registrations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_event_registrations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_event_registrations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_event_registrations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_event_registrations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_event_registrations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_event_registrations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_event_registrations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_event_registrations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_event_registrations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_event_registrations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_event_registrations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_event_registrations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_event_registrations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_event_registrations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_marathon_registrations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_marathon_registrations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_marathon_registrations_table_name_check CHECK ((table_name = 'user_marathon_registrations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_marathon_registrations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_marathon_registrations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_marathon_registrations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_messages; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_messages (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_messages_table_name_check CHECK ((table_name = 'user_messages'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_messages.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_messages.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_messages.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_messages.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_messages.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_messages.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_messages.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_messages.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_messages.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_messages.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_messages.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_messages.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_messages.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_messages.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_messages.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_messages.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_messages.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_messages.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_messages.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_messages.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_messages.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_messages.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_messages.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_overrides; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_overrides (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_overrides_table_name_check CHECK ((table_name = 'user_overrides'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_overrides.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_overrides.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_overrides.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_overrides.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_overrides.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_overrides.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_overrides.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_overrides.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_overrides.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_overrides.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_overrides.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_overrides.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_overrides.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_overrides.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_overrides.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_overrides.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_overrides.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_overrides.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_overrides.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_overrides.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_overrides.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_overrides.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_overrides.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_relations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_relations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_relations_table_name_check CHECK ((table_name = 'user_relations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_relations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_relations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_relations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_relations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_relations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_relations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_relations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_relations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_relations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_relations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_relations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_relations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_relations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_relations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_relations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_relations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_relations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_relations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_relations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_relations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_relations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_relations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_relations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_transfer_expectations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_transfer_expectations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_transfer_expectations_table_name_check CHECK ((table_name = 'user_transfer_expectations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_transfer_expectations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_transfer_expectations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_transfer_expectations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_travel_preparations; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_travel_preparations (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_travel_preparations_table_name_check CHECK ((table_name = 'user_travel_preparations'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_travel_preparations.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_travel_preparations.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_travel_preparations.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_travel_preparations.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_travel_preparations.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_travel_preparations.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_travel_preparations.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_travel_preparations.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_travel_preparations.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_travel_preparations.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_travel_preparations.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_travel_preparations.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_travel_preparations.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_travel_preparations.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_travel_preparations.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_travel_preparations.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_travel_preparations.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_user_uniform_orders; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_user_uniform_orders (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_user_uniform_orders_table_name_check CHECK ((table_name = 'user_uniform_orders'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_user_uniform_orders.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_user_uniform_orders.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_user_uniform_orders.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_uniform_orders.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_user_uniform_orders.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_user_uniform_orders.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_uniform_orders.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_user_uniform_orders.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_user_uniform_orders.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_user_uniform_orders.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_uniform_orders.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_user_uniform_orders.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_user_uniform_orders.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_user_uniform_orders.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_user_uniform_orders.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_user_uniform_orders.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_user_uniform_orders.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_users; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.logged_actions_users (
    event_id bigint DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass),
    schema_name text,
    table_name text,
    full_name text,
    relid oid,
    session_user_name text,
    app_user_id integer,
    app_user_type text,
    app_ip_address inet,
    action_tstamp_tx timestamp with time zone,
    action_tstamp_stm timestamp with time zone,
    action_tstamp_clk timestamp with time zone,
    transaction_id bigint,
    application_name text,
    client_addr inet,
    client_port integer,
    client_query text,
    action text,
    row_id bigint,
    row_data public.hstore,
    changed_fields public.hstore,
    statement_only boolean,
    CONSTRAINT logged_actions_action_check CHECK ((action = ANY (ARRAY['I'::text, 'D'::text, 'U'::text, 'T'::text, 'A'::text]))),
    CONSTRAINT logged_actions_users_table_name_check CHECK ((table_name = 'users'::text))
)
INHERITS (auditing.logged_actions);


--
-- Name: COLUMN logged_actions_users.event_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.event_id IS 'Unique identifier for each auditable event';


--
-- Name: COLUMN logged_actions_users.schema_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.schema_name IS 'Database schema audited table for this event is in';


--
-- Name: COLUMN logged_actions_users.table_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.table_name IS 'Non-schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_users.full_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.full_name IS 'schema-qualified table name of table event occured in';


--
-- Name: COLUMN logged_actions_users.relid; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.relid IS 'Table OID. Changes with drop/create. Get with ''tablename''::regclass';


--
-- Name: COLUMN logged_actions_users.session_user_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.session_user_name IS 'Login / session user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_users.app_user_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.app_user_id IS 'Application-provided polymorphic user id';


--
-- Name: COLUMN logged_actions_users.app_user_type; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.app_user_type IS 'Application-provided polymorphic user type';


--
-- Name: COLUMN logged_actions_users.app_ip_address; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.app_ip_address IS 'Application-provided ip address of user whose statement caused the audited event';


--
-- Name: COLUMN logged_actions_users.action_tstamp_tx; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.action_tstamp_tx IS 'Transaction start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_users.action_tstamp_stm; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.action_tstamp_stm IS 'Statement start timestamp for tx in which audited event occurred';


--
-- Name: COLUMN logged_actions_users.action_tstamp_clk; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.action_tstamp_clk IS 'Wall clock time at which audited event''s trigger call occurred';


--
-- Name: COLUMN logged_actions_users.transaction_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.transaction_id IS 'Identifier of transaction that made the change. May wrap, but unique paired with action_tstamp_tx.';


--
-- Name: COLUMN logged_actions_users.application_name; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.application_name IS 'Application name set when this audit event occurred. Can be changed in-session by client.';


--
-- Name: COLUMN logged_actions_users.client_addr; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.client_addr IS 'IP address of client that issued query. Null for unix domain socket.';


--
-- Name: COLUMN logged_actions_users.client_port; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.client_port IS 'Remote peer IP port address of client that issued query. Undefined for unix socket.';


--
-- Name: COLUMN logged_actions_users.client_query; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.client_query IS 'Top-level query that caused this auditable event. May be more than one statement.';


--
-- Name: COLUMN logged_actions_users.action; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.action IS 'Action type; I = insert, D = delete, U = update, T = truncate, A = archive';


--
-- Name: COLUMN logged_actions_users.row_id; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.row_id IS 'Record primary_key. Null for statement-level trigger. Prefers NEW.id if exists';


--
-- Name: COLUMN logged_actions_users.row_data; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.row_data IS 'Record value. Null for statement-level trigger. For INSERT this is the new tuple. For DELETE and UPDATE it is the old tuple.';


--
-- Name: COLUMN logged_actions_users.changed_fields; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.changed_fields IS 'New values of fields changed by UPDATE. Null except for row-level UPDATE events.';


--
-- Name: COLUMN logged_actions_users.statement_only; Type: COMMENT; Schema: auditing; Owner: -
--

COMMENT ON COLUMN auditing.logged_actions_users.statement_only IS '''t'' if audit event is from an FOR EACH STATEMENT trigger, ''f'' for FOR EACH ROW';


--
-- Name: logged_actions_view; Type: VIEW; Schema: auditing; Owner: -
--

CREATE VIEW auditing.logged_actions_view AS
 SELECT logged_actions.event_id,
    logged_actions.schema_name,
    logged_actions.table_name,
    logged_actions.full_name,
    logged_actions.relid,
    logged_actions.session_user_name,
    logged_actions.app_user_id,
    logged_actions.app_user_type,
    logged_actions.app_ip_address,
    logged_actions.action_tstamp_tx,
    logged_actions.action_tstamp_stm,
    logged_actions.action_tstamp_clk,
    logged_actions.transaction_id,
    logged_actions.application_name,
    logged_actions.client_addr,
    logged_actions.client_port,
    logged_actions.client_query,
    logged_actions.action,
    logged_actions.row_id,
    logged_actions.row_data,
    logged_actions.changed_fields,
    logged_actions.statement_only
   FROM auditing.logged_actions;


--
-- Name: table_sizes; Type: TABLE; Schema: auditing; Owner: -
--

CREATE TABLE auditing.table_sizes (
    oid bigint NOT NULL,
    schema character varying,
    name character varying,
    apx_row_count double precision,
    total_bytes bigint,
    idx_bytes bigint,
    toast_bytes bigint,
    tbl_bytes bigint,
    total text,
    idx text,
    toast text,
    tbl text,
    updated_at timestamp without time zone DEFAULT now()
)
WITH (autovacuum_vacuum_scale_factor='0.2');


--
-- Name: active_locks; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.active_locks AS
 SELECT t.schemaname,
    t.relname,
    l.locktype,
    l.page,
    l.virtualtransaction,
    l.pid,
    l.mode,
    l.granted
   FROM (pg_locks l
     JOIN pg_stat_all_tables t ON ((l.relation = t.relid)))
  WHERE ((t.schemaname <> 'pg_toast'::name) AND (t.schemaname <> 'pg_catalog'::name))
  ORDER BY t.schemaname, t.relname;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    byte_size bigint NOT NULL,
    checksum character varying NOT NULL,
    created_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: address_variants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.address_variants (
    id bigint NOT NULL,
    address_id bigint,
    candidate_ids integer[] DEFAULT '{}'::integer[] NOT NULL,
    value text NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: address_variants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.address_variants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: address_variants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.address_variants_id_seq OWNED BY public.address_variants.id;


--
-- Name: addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.addresses (
    id bigint NOT NULL,
    student_list_id bigint,
    is_foreign boolean DEFAULT false NOT NULL,
    street text NOT NULL,
    street_2 text,
    street_3 text,
    city text,
    state_id bigint,
    province text,
    zip text NOT NULL,
    country text,
    tz_offset integer DEFAULT 0 NOT NULL,
    dst boolean DEFAULT false NOT NULL,
    rejected boolean DEFAULT false NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT address_state_and_city_or_province_and_country_exists CHECK ((((state_id IS NOT NULL) AND (city IS NOT NULL)) OR ((province IS NOT NULL) AND (country IS NOT NULL))))
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.addresses_id_seq OWNED BY public.addresses.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp without time zone NOT NULL,
    updated_at timestamp without time zone NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: athletes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.athletes (
    id bigint NOT NULL,
    school_id bigint,
    source_id bigint,
    sport_id bigint,
    competing_team_id bigint,
    referring_coach_id bigint,
    grad integer,
    student_list_date date,
    respond_date date,
    original_school_name text,
    txfr_school_id integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: athletes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.athletes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: athletes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.athletes_id_seq OWNED BY public.athletes.id;


--
-- Name: athletes_sports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.athletes_sports (
    id bigint NOT NULL,
    athlete_id bigint,
    sport_id bigint,
    rank integer,
    main_event text,
    main_event_best text,
    stats text,
    invited boolean DEFAULT false NOT NULL,
    invited_date date,
    height text,
    weight text,
    handicap text,
    handicap_category text,
    years_played integer,
    special_teams boolean DEFAULT false NOT NULL,
    positions_array text[] DEFAULT '{}'::text[] NOT NULL,
    submitted_info boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    transferability public.transferability
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: athletes_sports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.athletes_sports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: athletes_sports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.athletes_sports_id_seq OWNED BY public.athletes_sports.id;


--
-- Name: better_record_attachment_validations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.better_record_attachment_validations (
    id bigint NOT NULL,
    name text NOT NULL,
    attachment_id bigint NOT NULL,
    ran boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: better_record_attachment_validations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.better_record_attachment_validations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: better_record_attachment_validations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.better_record_attachment_validations_id_seq OWNED BY public.better_record_attachment_validations.id;


--
-- Name: chat_room_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_room_messages (
    id bigint NOT NULL,
    chat_room_id uuid NOT NULL,
    user_id bigint,
    message text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: chat_room_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.chat_room_messages_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: chat_room_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.chat_room_messages_id_seq OWNED BY public.chat_room_messages.id;


--
-- Name: chat_rooms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_rooms (
    id uuid DEFAULT public.gen_random_uuid() NOT NULL,
    name text,
    email text,
    phone text,
    is_closed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: coaches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coaches (
    id bigint NOT NULL,
    school_id bigint NOT NULL,
    head_coach_id bigint,
    sport_id bigint,
    competing_team_id bigint,
    checked_background boolean DEFAULT false NOT NULL,
    deposits integer DEFAULT 0 NOT NULL,
    polo_size text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: coaches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.coaches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: coaches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.coaches_id_seq OWNED BY public.coaches.id;


--
-- Name: competing_teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competing_teams (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    name text NOT NULL,
    letter text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: competing_teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.competing_teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: competing_teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.competing_teams_id_seq OWNED BY public.competing_teams.id;


--
-- Name: competing_teams_travelers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competing_teams_travelers (
    id bigint NOT NULL,
    competing_team_id bigint NOT NULL,
    traveler_id bigint NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: competing_teams_travelers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.competing_teams_travelers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: competing_teams_travelers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.competing_teams_travelers_id_seq OWNED BY public.competing_teams_travelers.id;


--
-- Name: event_result_static_files; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_result_static_files (
    id bigint NOT NULL,
    event_result_id bigint NOT NULL,
    name text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: event_result_static_files_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_result_static_files_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_result_static_files_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_result_static_files_id_seq OWNED BY public.event_result_static_files.id;


--
-- Name: event_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.event_results (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    name text NOT NULL,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: event_results_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.event_results_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: event_results_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.event_results_id_seq OWNED BY public.event_results.id;


--
-- Name: flight_airports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flight_airports (
    id bigint NOT NULL,
    code text NOT NULL,
    name text NOT NULL,
    carrier text DEFAULT 'qantas'::text NOT NULL,
    cost public.money_integer,
    location_override text,
    address_id bigint,
    tz_offset integer DEFAULT 0 NOT NULL,
    dst boolean DEFAULT true NOT NULL,
    preferred boolean DEFAULT false NOT NULL,
    selectable boolean DEFAULT true NOT NULL,
    track_departing_date date,
    track_returning_date date,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: flight_airports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flight_airports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flight_airports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flight_airports_id_seq OWNED BY public.flight_airports.id;


--
-- Name: flight_legs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flight_legs (
    id bigint NOT NULL,
    schedule_id bigint NOT NULL,
    flight_number text,
    departing_airport_id bigint NOT NULL,
    departing_at timestamp without time zone NOT NULL,
    arriving_airport_id bigint NOT NULL,
    arriving_at timestamp without time zone NOT NULL,
    overnight boolean DEFAULT false NOT NULL,
    is_subsidiary boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: flight_legs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flight_legs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flight_legs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flight_legs_id_seq OWNED BY public.flight_legs.id;


--
-- Name: flight_schedules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flight_schedules (
    id bigint NOT NULL,
    parent_schedule_id bigint,
    verified_by_id bigint,
    pnr text NOT NULL,
    carrier_pnr text,
    operator text,
    route_summary text NOT NULL,
    booking_reference text,
    amount public.money_integer,
    seats_reserved integer DEFAULT 0 NOT NULL,
    names_assigned integer DEFAULT 0 NOT NULL,
    original_value text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: flight_schedules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flight_schedules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flight_schedules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flight_schedules_id_seq OWNED BY public.flight_schedules.id;


--
-- Name: flight_tickets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.flight_tickets (
    id bigint NOT NULL,
    schedule_id bigint NOT NULL,
    traveler_id bigint NOT NULL,
    ticketed boolean DEFAULT false NOT NULL,
    required boolean DEFAULT false NOT NULL,
    ticket_number text,
    is_checked_in boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: flight_tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.flight_tickets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: flight_tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.flight_tickets_id_seq OWNED BY public.flight_tickets.id;


--
-- Name: fundraising_idea_images; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fundraising_idea_images (
    id bigint NOT NULL,
    fundraising_idea_id bigint NOT NULL,
    alt text,
    display_order integer,
    hide boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: fundraising_idea_images_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fundraising_idea_images_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fundraising_idea_images_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fundraising_idea_images_id_seq OWNED BY public.fundraising_idea_images.id;


--
-- Name: fundraising_ideas; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fundraising_ideas (
    id bigint NOT NULL,
    title text NOT NULL,
    description text,
    display_order integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: fundraising_ideas_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fundraising_ideas_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fundraising_ideas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fundraising_ideas_id_seq OWNED BY public.fundraising_ideas.id;


--
-- Name: import_athletes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_athletes (
    id bigint NOT NULL,
    first text NOT NULL,
    last text NOT NULL,
    gender text NOT NULL,
    grad integer NOT NULL,
    stats text NOT NULL,
    event_list jsonb DEFAULT '{}'::jsonb NOT NULL,
    school_name text NOT NULL,
    school_class text,
    school_id bigint,
    state_id bigint,
    sport_id bigint,
    source_name text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: import_athletes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_athletes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_athletes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_athletes_id_seq OWNED BY public.import_athletes.id;


--
-- Name: import_backups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_backups (
    id bigint NOT NULL,
    upload_type text NOT NULL,
    "values" jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: import_backups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_backups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_backups_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_backups_id_seq OWNED BY public.import_backups.id;


--
-- Name: import_errors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_errors (
    id bigint NOT NULL,
    upload_type text NOT NULL,
    "values" jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: import_errors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_errors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_errors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_errors_id_seq OWNED BY public.import_errors.id;


--
-- Name: import_matches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_matches (
    id bigint NOT NULL,
    name text NOT NULL,
    school_id bigint,
    state_id bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: import_matches_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.import_matches_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: import_matches_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.import_matches_id_seq OWNED BY public.import_matches.id;


--
-- Name: interests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interests (
    id bigint NOT NULL,
    level text,
    contactable boolean DEFAULT false NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: interests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.interests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: interests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.interests_id_seq OWNED BY public.interests.id;


--
-- Name: invite_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invite_rules (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    state_id bigint NOT NULL,
    invitable boolean DEFAULT false NOT NULL,
    certifiable boolean DEFAULT false NOT NULL,
    grad_year integer DEFAULT 2022 NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: invite_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invite_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invite_rules_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invite_rules_id_seq OWNED BY public.invite_rules.id;


--
-- Name: invite_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.invite_stats (
    id bigint NOT NULL,
    submitted date,
    mailed date,
    estimated integer,
    actual integer,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: invite_stats_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.invite_stats_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: invite_stats_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.invite_stats_id_seq OWNED BY public.invite_stats.id;


--
-- Name: mailings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mailings (
    id bigint NOT NULL,
    user_id bigint,
    category text,
    sent date,
    explicit boolean DEFAULT false NOT NULL,
    printed boolean DEFAULT false NOT NULL,
    is_home boolean DEFAULT false NOT NULL,
    is_foreign boolean DEFAULT false NOT NULL,
    auto boolean DEFAULT false NOT NULL,
    failed boolean DEFAULT false NOT NULL,
    street text NOT NULL,
    street_2 text,
    street_3 text,
    city text NOT NULL,
    state text NOT NULL,
    zip text NOT NULL,
    country text DEFAULT 'USA'::text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: mailings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.mailings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: mailings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.mailings_id_seq OWNED BY public.mailings.id;


--
-- Name: meeting_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_registrations (
    id bigint NOT NULL,
    meeting_id bigint NOT NULL,
    user_id bigint NOT NULL,
    athlete_id bigint,
    attended boolean DEFAULT false NOT NULL,
    duration interval DEFAULT '00:00:00'::interval NOT NULL,
    questions text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: meeting_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_registrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_registrations_id_seq OWNED BY public.meeting_registrations.id;


--
-- Name: meeting_video_views; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_video_views (
    id bigint NOT NULL,
    video_id bigint NOT NULL,
    user_id bigint NOT NULL,
    athlete_id bigint,
    watched boolean DEFAULT false NOT NULL,
    duration interval DEFAULT '00:00:00'::interval NOT NULL,
    questions text[] DEFAULT '{}'::text[] NOT NULL,
    first_viewed_at timestamp without time zone,
    first_watched_at timestamp without time zone,
    last_viewed_at timestamp without time zone,
    gave_offer boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: meeting_video_views_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_video_views_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_video_views_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_video_views_id_seq OWNED BY public.meeting_video_views.id;


--
-- Name: meeting_videos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meeting_videos (
    id bigint NOT NULL,
    category public.meeting_category NOT NULL,
    link text NOT NULL,
    duration interval DEFAULT '00:00:00'::interval NOT NULL,
    minimum_percentage public.exchange_rate_integer DEFAULT '2500000000'::bigint NOT NULL,
    sent integer DEFAULT 0 NOT NULL,
    viewed integer DEFAULT 0 NOT NULL,
    offer jsonb DEFAULT '{}'::jsonb NOT NULL,
    offer_exceptions_array text[] DEFAULT '{}'::text[] NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: meeting_videos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meeting_videos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meeting_videos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meeting_videos_id_seq OWNED BY public.meeting_videos.id;


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id bigint NOT NULL,
    category public.meeting_category NOT NULL,
    host_id bigint NOT NULL,
    tech_id bigint NOT NULL,
    start_time timestamp without time zone NOT NULL,
    duration interval DEFAULT '00:00:00'::interval NOT NULL,
    registered integer DEFAULT 0 NOT NULL,
    attended integer DEFAULT 0 NOT NULL,
    represented_registered integer DEFAULT 0 NOT NULL,
    represented_attended integer DEFAULT 0 NOT NULL,
    webinar_uuid text,
    session_uuid text,
    join_link text,
    recording_link text,
    notes text,
    questions text,
    offer jsonb DEFAULT '{}'::jsonb NOT NULL,
    offer_exceptions_array text[] DEFAULT '{}'::text[] NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: meetings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.meetings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: meetings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.meetings_id_seq OWNED BY public.meetings.id;


--
-- Name: officials; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.officials (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    state_id bigint NOT NULL,
    category text DEFAULT 'official'::text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: officials_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.officials_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: officials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.officials_id_seq OWNED BY public.officials.id;


--
-- Name: participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participants (
    id bigint NOT NULL,
    name text,
    gender public.gender DEFAULT 'U'::public.gender NOT NULL,
    state_id bigint NOT NULL,
    sport_id bigint,
    sport_name text,
    school text,
    fundraising_time integer,
    trip_cost integer,
    category text DEFAULT 'athlete'::text,
    year text DEFAULT '2018'::text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: participants_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.participants_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: participants_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.participants_id_seq OWNED BY public.participants.id;


--
-- Name: payment_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_items (
    id bigint NOT NULL,
    payment_id bigint NOT NULL,
    traveler_id bigint,
    amount public.money_integer DEFAULT 0 NOT NULL,
    price public.money_integer DEFAULT 0 NOT NULL,
    quantity integer DEFAULT 1 NOT NULL,
    name text DEFAULT 'Account Payment'::text NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: payment_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_items_id_seq OWNED BY public.payment_items.id;


--
-- Name: payment_join_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_join_terms (
    id bigint NOT NULL,
    payment_id integer NOT NULL,
    terms_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_join_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_join_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_join_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_join_terms_id_seq OWNED BY public.payment_join_terms.id;


--
-- Name: payment_remittances; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_remittances (
    id bigint NOT NULL,
    remit_number text,
    recorded boolean DEFAULT false NOT NULL,
    reconciled boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: payment_remittances_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_remittances_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_remittances_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_remittances_id_seq OWNED BY public.payment_remittances.id;


--
-- Name: payment_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payment_terms (
    id bigint NOT NULL,
    edited_by_id bigint NOT NULL,
    body text NOT NULL,
    minor_signed_terms_link text NOT NULL,
    adult_signed_terms_link text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: payment_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payment_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payment_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payment_terms_id_seq OWNED BY public.payment_terms.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    shirt_order_id bigint,
    gateway_type text DEFAULT 'braintree'::text NOT NULL,
    successful boolean DEFAULT false NOT NULL,
    amount public.money_integer NOT NULL,
    category text DEFAULT 'account'::text NOT NULL,
    remit_number text DEFAULT ((now())::date || '-CC'::text) NOT NULL,
    status text,
    transaction_type text,
    transaction_id text,
    billing jsonb DEFAULT '{}'::jsonb NOT NULL,
    processor jsonb DEFAULT '{}'::jsonb NOT NULL,
    settlement jsonb DEFAULT '{}'::jsonb NOT NULL,
    gateway jsonb DEFAULT '{}'::jsonb NOT NULL,
    risk jsonb DEFAULT '{}'::jsonb NOT NULL,
    anonymous boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    reconciled_date date
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: privacy_policies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.privacy_policies (
    id bigint NOT NULL,
    edited_by_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: privacy_policies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.privacy_policies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: privacy_policies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.privacy_policies_id_seq OWNED BY public.privacy_policies.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id bigint NOT NULL,
    pid text NOT NULL,
    address_id bigint,
    name text NOT NULL,
    allowed boolean DEFAULT true NOT NULL,
    allowed_home boolean DEFAULT true NOT NULL,
    closed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: schools_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.schools_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: schools_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.schools_id_seq OWNED BY public.schools.id;


--
-- Name: sent_mails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sent_mails (
    id bigint NOT NULL,
    name text,
    created_at timestamp without time zone DEFAULT now()
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: sent_mails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sent_mails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sent_mails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sent_mails_id_seq OWNED BY public.sent_mails.id;


--
-- Name: shirt_order_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shirt_order_items (
    id bigint NOT NULL,
    shirt_order_id bigint NOT NULL,
    size text NOT NULL,
    is_youth boolean DEFAULT false NOT NULL,
    quantity integer DEFAULT 0 NOT NULL,
    price public.money_integer DEFAULT 0 NOT NULL,
    sent_count integer DEFAULT 0 NOT NULL,
    complete boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: shirt_order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shirt_order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shirt_order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shirt_order_items_id_seq OWNED BY public.shirt_order_items.id;


--
-- Name: shirt_order_shipments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shirt_order_shipments (
    id bigint NOT NULL,
    shirt_order_id bigint NOT NULL,
    shirts jsonb DEFAULT '{}'::jsonb NOT NULL,
    shirts_count integer DEFAULT 0 NOT NULL,
    sent date DEFAULT (now())::date NOT NULL,
    shipped_to jsonb DEFAULT '{}'::jsonb NOT NULL,
    failed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: shirt_order_shipments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shirt_order_shipments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shirt_order_shipments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shirt_order_shipments_id_seq OWNED BY public.shirt_order_shipments.id;


--
-- Name: shirt_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.shirt_orders (
    id bigint NOT NULL,
    total_price public.money_integer DEFAULT 0 NOT NULL,
    shirts_ordered integer DEFAULT 0 NOT NULL,
    shirts_sent integer DEFAULT 0 NOT NULL,
    shipping jsonb DEFAULT '{}'::jsonb NOT NULL,
    complete boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: shirt_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.shirt_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: shirt_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.shirt_orders_id_seq OWNED BY public.shirt_orders.id;


--
-- Name: sources; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sources (
    id bigint NOT NULL,
    name text NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: sources_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sources_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sources_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sources_id_seq OWNED BY public.sources.id;


--
-- Name: sport_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sport_events (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    name text,
    pattern text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: sport_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sport_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sport_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sport_events_id_seq OWNED BY public.sport_events.id;


--
-- Name: sport_infos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sport_infos (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    title text NOT NULL,
    tournament text NOT NULL,
    first_year integer NOT NULL,
    departing_dates text NOT NULL,
    returning_dates text NOT NULL,
    team_count text NOT NULL,
    team_size text NOT NULL,
    description text NOT NULL,
    bullet_points_array text[] DEFAULT '{}'::text[] NOT NULL,
    programs_array text[] DEFAULT '{}'::text[] NOT NULL,
    background_image text,
    additional text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: sport_infos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sport_infos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sport_infos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sport_infos_id_seq OWNED BY public.sport_infos.id;


--
-- Name: sports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sports (
    id bigint NOT NULL,
    abbr text NOT NULL,
    "full" text NOT NULL,
    abbr_gender text NOT NULL,
    full_gender text NOT NULL,
    is_numbered boolean DEFAULT false NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: sports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sports_id_seq OWNED BY public.sports.id;


--
-- Name: staff_assignment_visits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_assignment_visits (
    id bigint NOT NULL,
    assignment_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: staff_assignment_visits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_assignment_visits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_assignment_visits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_assignment_visits_id_seq OWNED BY public.staff_assignment_visits.id;


--
-- Name: staff_assignments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_assignments (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    assigned_to_id bigint NOT NULL,
    assigned_by_id bigint NOT NULL,
    reason text DEFAULT 'Follow Up'::text,
    completed boolean DEFAULT false NOT NULL,
    unneeded boolean DEFAULT false NOT NULL,
    reviewed boolean DEFAULT false NOT NULL,
    locked boolean DEFAULT false NOT NULL,
    completed_at timestamp without time zone,
    unneeded_at timestamp without time zone,
    reviewed_at timestamp without time zone,
    follow_up_date date,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: staff_assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_assignments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_assignments_id_seq OWNED BY public.staff_assignments.id;


--
-- Name: staff_clocks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staff_clocks (
    id bigint NOT NULL,
    staff_id bigint NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: staff_clocks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staff_clocks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staff_clocks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staff_clocks_id_seq OWNED BY public.staff_clocks.id;


--
-- Name: staffs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.staffs (
    id bigint NOT NULL,
    admin boolean DEFAULT false NOT NULL,
    trusted boolean DEFAULT false NOT NULL,
    management boolean DEFAULT false NOT NULL,
    australia boolean DEFAULT false NOT NULL,
    credits boolean DEFAULT false NOT NULL,
    debits boolean DEFAULT false NOT NULL,
    finances boolean DEFAULT false NOT NULL,
    flights boolean DEFAULT false NOT NULL,
    importing boolean DEFAULT false NOT NULL,
    inventories boolean DEFAULT false NOT NULL,
    meetings boolean DEFAULT false NOT NULL,
    offers boolean DEFAULT false NOT NULL,
    passports boolean DEFAULT false NOT NULL,
    photos boolean DEFAULT false NOT NULL,
    recaps boolean DEFAULT false NOT NULL,
    remittances boolean DEFAULT false NOT NULL,
    schools boolean DEFAULT false NOT NULL,
    uniforms boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: staffs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.staffs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: staffs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.staffs_id_seq OWNED BY public.staffs.id;


--
-- Name: states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.states (
    id bigint NOT NULL,
    abbr text NOT NULL,
    "full" text NOT NULL,
    conference text,
    is_foreign boolean DEFAULT false NOT NULL,
    tz_offset integer DEFAULT 0 NOT NULL,
    dst boolean DEFAULT false NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: states_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.states_id_seq OWNED BY public.states.id;


--
-- Name: student_lists; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.student_lists (
    id bigint NOT NULL,
    sent date NOT NULL,
    received date
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: student_lists_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.student_lists_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: student_lists_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.student_lists_id_seq OWNED BY public.student_lists.id;


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    name text,
    sport_id bigint NOT NULL,
    state_id bigint NOT NULL,
    competing_team_id bigint,
    departing_date date,
    returning_date date,
    gbr_date date,
    gbr_seats integer,
    default_bus text,
    default_wristband text,
    default_hotel text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: teams_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.teams_id_seq OWNED BY public.teams.id;


--
-- Name: thank_you_ticket_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thank_you_ticket_terms (
    id bigint NOT NULL,
    edited_by_id bigint NOT NULL,
    body text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: thank_you_ticket_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thank_you_ticket_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thank_you_ticket_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thank_you_ticket_terms_id_seq OWNED BY public.thank_you_ticket_terms.id;


--
-- Name: traveler_base_debits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_base_debits (
    id bigint NOT NULL,
    amount public.money_integer,
    name text NOT NULL,
    description text,
    is_default boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: traveler_base_debits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_base_debits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_base_debits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_base_debits_id_seq OWNED BY public.traveler_base_debits.id;


--
-- Name: traveler_buses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_buses (
    id bigint NOT NULL,
    sport_id bigint NOT NULL,
    hotel_id bigint,
    capacity integer DEFAULT 0 NOT NULL,
    color text NOT NULL,
    name text NOT NULL,
    details text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: traveler_buses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_buses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_buses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_buses_id_seq OWNED BY public.traveler_buses.id;


--
-- Name: traveler_buses_travelers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_buses_travelers (
    traveler_id bigint NOT NULL,
    bus_id bigint NOT NULL
);


--
-- Name: traveler_credits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_credits (
    id bigint NOT NULL,
    traveler_id bigint NOT NULL,
    assigner_id bigint,
    amount public.money_integer,
    name text NOT NULL,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: traveler_credits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_credits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_credits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_credits_id_seq OWNED BY public.traveler_credits.id;


--
-- Name: traveler_debits; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_debits (
    id bigint NOT NULL,
    base_debit_id bigint NOT NULL,
    traveler_id bigint NOT NULL,
    assigner_id bigint,
    amount public.money_integer,
    name text,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: traveler_debits_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_debits_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_debits_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_debits_id_seq OWNED BY public.traveler_debits.id;


--
-- Name: traveler_hotels; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_hotels (
    id bigint NOT NULL,
    name text NOT NULL,
    address_id bigint NOT NULL,
    phone text,
    contacts jsonb DEFAULT '[]'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: traveler_hotels_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_hotels_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_hotels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_hotels_id_seq OWNED BY public.traveler_hotels.id;


--
-- Name: traveler_offers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_offers (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    assigner_id bigint,
    rules text[] DEFAULT '{}'::text[],
    amount public.money_integer,
    minimum public.money_integer,
    maximum public.money_integer,
    expiration_date date,
    name text,
    description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: traveler_offers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_offers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_offers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_offers_id_seq OWNED BY public.traveler_offers.id;


--
-- Name: traveler_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_requests (
    id bigint NOT NULL,
    traveler_id bigint NOT NULL,
    category public.traveler_request_category NOT NULL,
    details text NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: traveler_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_requests_id_seq OWNED BY public.traveler_requests.id;


--
-- Name: traveler_rooms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.traveler_rooms (
    id bigint NOT NULL,
    traveler_id bigint NOT NULL,
    hotel_id bigint NOT NULL,
    number text,
    check_in_date date NOT NULL,
    check_out_date date NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: traveler_rooms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.traveler_rooms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: traveler_rooms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.traveler_rooms_id_seq OWNED BY public.traveler_rooms.id;


--
-- Name: travelers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.travelers (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    team_id bigint NOT NULL,
    balance public.money_integer NOT NULL,
    shirt_size text,
    departing_date date,
    departing_from text,
    returning_date date,
    returning_to text,
    bus text,
    wristband text,
    hotel text,
    has_ground_transportation boolean DEFAULT true NOT NULL,
    has_lodging boolean DEFAULT true NOT NULL,
    has_gbr boolean DEFAULT false NOT NULL,
    own_flights boolean DEFAULT false NOT NULL,
    cancel_date date,
    cancel_reason text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: travelers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.travelers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: travelers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.travelers_id_seq OWNED BY public.travelers.id;


--
-- Name: unsubscribers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.unsubscribers (
    id bigint NOT NULL,
    category public.unsubscriber_category,
    value text NOT NULL,
    "all" boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: unsubscribers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.unsubscribers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: unsubscribers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.unsubscribers_id_seq OWNED BY public.unsubscribers.id;


--
-- Name: user_ambassadors; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_ambassadors (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ambassador_user_id bigint NOT NULL,
    types_array text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_ambassadors_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_ambassadors_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_ambassadors_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_ambassadors_id_seq OWNED BY public.user_ambassadors.id;


--
-- Name: user_event_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_event_registrations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    submitter_id bigint,
    event_100_m text[] DEFAULT '{}'::text[],
    event_100_m_count integer DEFAULT 0 NOT NULL,
    event_100_m_time text,
    event_200_m text[] DEFAULT '{}'::text[],
    event_200_m_count integer DEFAULT 0 NOT NULL,
    event_200_m_time text,
    event_400_m text[] DEFAULT '{}'::text[],
    event_400_m_count integer DEFAULT 0 NOT NULL,
    event_400_m_time text,
    event_800_m text[] DEFAULT '{}'::text[],
    event_800_m_count integer DEFAULT 0 NOT NULL,
    event_800_m_time text,
    event_1500_m text[] DEFAULT '{}'::text[],
    event_1500_m_count integer DEFAULT 0 NOT NULL,
    event_1500_m_time text,
    event_3000_m text[] DEFAULT '{}'::text[],
    event_3000_m_count integer DEFAULT 0 NOT NULL,
    event_3000_m_time text,
    event_90_m_hurdles text[] DEFAULT '{}'::text[],
    event_90_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_90_m_hurdles_time text,
    event_100_m_hurdles text[] DEFAULT '{}'::text[],
    event_100_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_100_m_hurdles_time text,
    event_110_m_hurdles text[] DEFAULT '{}'::text[],
    event_110_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_110_m_hurdles_time text,
    event_200_m_hurdles text[] DEFAULT '{}'::text[],
    event_200_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_200_m_hurdles_time text,
    event_300_m_hurdles text[] DEFAULT '{}'::text[],
    event_300_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_300_m_hurdles_time text,
    event_400_m_hurdles text[] DEFAULT '{}'::text[],
    event_400_m_hurdles_count integer DEFAULT 0 NOT NULL,
    event_400_m_hurdles_time text,
    event_2000_m_steeple text[] DEFAULT '{}'::text[],
    event_2000_m_steeple_count integer DEFAULT 0 NOT NULL,
    event_2000_m_steeple_time text,
    event_long_jump text[] DEFAULT '{}'::text[],
    event_long_jump_count integer DEFAULT 0 NOT NULL,
    event_long_jump_time text,
    event_triple_jump text[] DEFAULT '{}'::text[],
    event_triple_jump_count integer DEFAULT 0 NOT NULL,
    event_triple_jump_time text,
    event_high_jump text[] DEFAULT '{}'::text[],
    event_high_jump_count integer DEFAULT 0 NOT NULL,
    event_high_jump_time text,
    event_pole_vault text[] DEFAULT '{}'::text[],
    event_pole_vault_count integer DEFAULT 0 NOT NULL,
    event_pole_vault_time text,
    event_shot_put text[] DEFAULT '{}'::text[],
    event_shot_put_count integer DEFAULT 0 NOT NULL,
    event_shot_put_time text,
    event_discus text[] DEFAULT '{}'::text[],
    event_discus_count integer DEFAULT 0 NOT NULL,
    event_discus_time text,
    event_javelin text[] DEFAULT '{}'::text[],
    event_javelin_count integer DEFAULT 0 NOT NULL,
    event_javelin_time text,
    event_hammer text[] DEFAULT '{}'::text[],
    event_hammer_count integer DEFAULT 0 NOT NULL,
    event_hammer_time text,
    event_3000_m_walk text[] DEFAULT '{}'::text[],
    event_3000_m_walk_count integer DEFAULT 0 NOT NULL,
    event_3000_m_walk_time text,
    event_5000_m_walk text[] DEFAULT '{}'::text[],
    event_5000_m_walk_count integer DEFAULT 0 NOT NULL,
    event_5000_m_walk_time text,
    one_hundred_m_relay text,
    four_hundred_m_relay text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_event_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_event_registrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_event_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_event_registrations_id_seq OWNED BY public.user_event_registrations.id;


--
-- Name: user_forwarded_ids; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_forwarded_ids (
    original_id text NOT NULL,
    dus_id text
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_interest_histories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_interest_histories (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    interest_id bigint NOT NULL,
    changed_by_id bigint,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: user_interest_histories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_interest_histories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_interest_histories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_interest_histories_id_seq OWNED BY public.user_interest_histories.id;


--
-- Name: user_marathon_registrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_marathon_registrations (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    registered_date date,
    confirmation text,
    email text DEFAULT 'gcm-registrations@downundersports.com'::text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_marathon_registrations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_marathon_registrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_marathon_registrations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_marathon_registrations_id_seq OWNED BY public.user_marathon_registrations.id;


--
-- Name: user_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_messages (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    staff_id bigint NOT NULL,
    type text NOT NULL,
    category text NOT NULL,
    reason text DEFAULT 'other'::text NOT NULL,
    message text NOT NULL,
    reviewed boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_messages_id_seq1; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_messages_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_messages_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_messages_id_seq1 OWNED BY public.user_messages.id;


--
-- Name: user_nationalities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_nationalities (
    id bigint NOT NULL,
    code text NOT NULL,
    country text,
    nationality text,
    visable boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_nationalities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_nationalities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_nationalities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_nationalities_id_seq OWNED BY public.user_nationalities.id;


--
-- Name: user_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_overrides (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    payment_description text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_overrides_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_overrides_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_overrides_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_overrides_id_seq OWNED BY public.user_overrides.id;


--
-- Name: user_passport_authorities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_passport_authorities (
    id bigint NOT NULL,
    name text NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_passport_authorities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_passport_authorities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_passport_authorities_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_passport_authorities_id_seq OWNED BY public.user_passport_authorities.id;


--
-- Name: user_passports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_passports (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    checker_id bigint,
    second_checker_id bigint,
    type text DEFAULT 'P'::text,
    code text DEFAULT 'USA'::text,
    nationality text DEFAULT 'UNITED STATES OF AMERICA'::text,
    authority text DEFAULT 'United States Department of State'::text,
    number text,
    surname text,
    given_names text,
    sex public.gender,
    birthplace text,
    birth_date date,
    issued_date date,
    expiration_date date,
    country_of_birth text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_passports_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_passports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_passports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_passports_id_seq OWNED BY public.user_passports.id;


--
-- Name: user_refund_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_refund_requests (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    value text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: user_refund_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_refund_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_refund_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_refund_requests_id_seq OWNED BY public.user_refund_requests.id;


--
-- Name: user_relations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_relations (
    id bigint NOT NULL,
    user_id bigint,
    related_user_id bigint,
    relationship text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_relations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_relations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_relations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_relations_id_seq OWNED BY public.user_relations.id;


--
-- Name: user_relationship_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_relationship_types (
    value text NOT NULL,
    inverse text NOT NULL
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: user_transfer_expectations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_transfer_expectations (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    difficulty public.difficulty_level,
    status public.transfer_contact_status,
    can_transfer public.three_state DEFAULT 'U'::public.three_state NOT NULL,
    can_compete public.three_state DEFAULT 'U'::public.three_state NOT NULL,
    notes text,
    offer jsonb DEFAULT '"{}"'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: user_transfer_expectations_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_transfer_expectations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_transfer_expectations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_transfer_expectations_id_seq OWNED BY public.user_transfer_expectations.id;


--
-- Name: user_travel_preparations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_travel_preparations (
    id bigint NOT NULL,
    user_id integer NOT NULL,
    applications jsonb DEFAULT '{}'::jsonb NOT NULL,
    calls jsonb DEFAULT '{}'::jsonb NOT NULL,
    confirmations jsonb DEFAULT '{}'::jsonb NOT NULL,
    deadlines jsonb DEFAULT '{}'::jsonb NOT NULL,
    emails jsonb DEFAULT '{}'::jsonb NOT NULL,
    followups jsonb DEFAULT '{}'::jsonb NOT NULL,
    items_received jsonb DEFAULT '{}'::jsonb NOT NULL,
    eta_email_date date,
    visa_message_sent_date date,
    extra_eta_processing boolean DEFAULT false NOT NULL,
    has_multiple_citizenships public.three_state DEFAULT 'U'::public.three_state NOT NULL,
    citizenships_array text[] DEFAULT '{}'::text[] NOT NULL,
    has_aliases public.three_state DEFAULT 'U'::public.three_state NOT NULL,
    aliases_array character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    has_convictions public.three_state DEFAULT 'U'::public.three_state NOT NULL,
    convictions_array text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: user_travel_preparations_id_seq1; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_travel_preparations_id_seq1
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_travel_preparations_id_seq1; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_travel_preparations_id_seq1 OWNED BY public.user_travel_preparations.id;


--
-- Name: user_uniform_orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_uniform_orders (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    submitter_id bigint NOT NULL,
    sport_id bigint NOT NULL,
    cost public.money_integer,
    is_reorder boolean DEFAULT false NOT NULL,
    jersey_size text,
    shorts_size text,
    jersey_count integer DEFAULT 1,
    shorts_count integer DEFAULT 1,
    jersey_number integer,
    preferred_number_1 integer,
    preferred_number_2 integer,
    preferred_number_3 integer,
    submitted_to_shop_at timestamp without time zone,
    paid_shop_at timestamp without time zone,
    invoice_date date,
    shipped_date date,
    shipping jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: user_uniform_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.user_uniform_orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: user_uniform_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.user_uniform_orders_id_seq OWNED BY public.user_uniform_orders.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    dus_id text DEFAULT public.unique_random_string('users'::text, 'dus_id'::text, 6) NOT NULL,
    category_type character varying,
    category_id bigint,
    email text,
    password text,
    register_secret text,
    certificate text,
    title text,
    first text NOT NULL,
    middle text,
    last text NOT NULL,
    suffix text,
    print_first_names text,
    print_other_names text,
    nick_name text,
    keep_name boolean DEFAULT false NOT NULL,
    address_id bigint,
    interest_id bigint DEFAULT 5 NOT NULL,
    extension text,
    phone text,
    can_text boolean DEFAULT true NOT NULL,
    gender public.gender DEFAULT 'U'::public.gender NOT NULL,
    shirt_size text,
    birth_date date,
    transfer_id integer,
    responded_at timestamp without time zone,
    is_verified boolean DEFAULT false NOT NULL,
    visible_until_year integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_email_must_exist_if_password_exists CHECK (((password IS NULL) OR (email IS NOT NULL))),
    CONSTRAINT user_has_valid_category CHECK ((((category_type IS NULL) AND (category_id IS NULL)) OR ((category_type)::text = ANY (ARRAY[('Athlete'::character varying)::text, ('Coach'::character varying)::text, ('Official'::character varying)::text, ('Staff'::character varying)::text, ('athletes'::character varying)::text, ('coaches'::character varying)::text, ('officials'::character varying)::text, ('staffs'::character varying)::text])))),
    CONSTRAINT user_has_valid_shirt_size CHECK (((shirt_size IS NULL) OR (shirt_size = ANY (ARRAY['Y-XS'::text, 'Y-S'::text, 'Y-M'::text, 'Y-L'::text, 'A-S'::text, 'A-M'::text, 'A-L'::text, 'A-XL'::text, 'A-2XL'::text, 'A-3XL'::text, 'A-4XL'::text]))))
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: view_trackers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.view_trackers (
    id bigint NOT NULL,
    name text NOT NULL,
    running boolean DEFAULT false NOT NULL,
    last_refresh timestamp without time zone
)
WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2');


--
-- Name: view_trackers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.view_trackers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: view_trackers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.view_trackers_id_seq OWNED BY public.view_trackers.id;


--
-- Name: competing_teams; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.competing_teams (
    operating_year integer DEFAULT 2019,
    CONSTRAINT competing_teams_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.competing_teams);


--
-- Name: competing_teams_travelers; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.competing_teams_travelers (
    operating_year integer DEFAULT 2019,
    CONSTRAINT competing_teams_travelers_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.competing_teams_travelers);


--
-- Name: flight_legs; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.flight_legs (
    operating_year integer DEFAULT 2019,
    CONSTRAINT flight_legs_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.flight_legs);


--
-- Name: flight_schedules; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.flight_schedules (
    operating_year integer DEFAULT 2019,
    CONSTRAINT flight_schedules_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.flight_schedules);


--
-- Name: flight_tickets; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.flight_tickets (
    operating_year integer DEFAULT 2019,
    CONSTRAINT flight_tickets_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.flight_tickets);


--
-- Name: mailings; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.mailings (
    operating_year integer DEFAULT 2019,
    CONSTRAINT mailings_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.mailings);


--
-- Name: meeting_registrations; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.meeting_registrations (
    operating_year integer DEFAULT 2019,
    CONSTRAINT meeting_registrations_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.meeting_registrations);


--
-- Name: meeting_video_views; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.meeting_video_views (
    operating_year integer DEFAULT 2019,
    CONSTRAINT meeting_video_views_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.meeting_video_views);


--
-- Name: payment_items; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.payment_items (
    operating_year integer DEFAULT 2019,
    CONSTRAINT payment_items_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.payment_items);


--
-- Name: payment_join_terms; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.payment_join_terms (
    operating_year integer DEFAULT 2019,
    CONSTRAINT payment_join_terms_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.payment_join_terms);


--
-- Name: payment_remittances; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.payment_remittances (
    operating_year integer DEFAULT 2019,
    CONSTRAINT payment_remittances_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.payment_remittances);


--
-- Name: payments; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.payments (
    operating_year integer DEFAULT 2019,
    CONSTRAINT payments_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.payments);


--
-- Name: sent_mails; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.sent_mails (
    operating_year integer DEFAULT 2019,
    CONSTRAINT sent_mails_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.sent_mails);


--
-- Name: staff_assignment_visits; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.staff_assignment_visits (
    operating_year integer DEFAULT 2019,
    CONSTRAINT staff_assignment_visits_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.staff_assignment_visits);


--
-- Name: staff_assignments; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.staff_assignments (
    operating_year integer DEFAULT 2019,
    CONSTRAINT staff_assignments_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.staff_assignments);


--
-- Name: student_lists; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.student_lists (
    operating_year integer DEFAULT 2019,
    CONSTRAINT student_lists_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.student_lists);


--
-- Name: teams; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.teams (
    operating_year integer DEFAULT 2019,
    CONSTRAINT teams_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.teams);


--
-- Name: traveler_buses; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_buses (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_buses_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_buses);


--
-- Name: traveler_buses_travelers; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_buses_travelers (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_buses_travelers_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_buses_travelers);


--
-- Name: traveler_credits; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_credits (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_credits_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_credits);


--
-- Name: traveler_debits; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_debits (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_debits_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_debits);


--
-- Name: traveler_offers; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_offers (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_offers_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_offers);


--
-- Name: traveler_requests; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_requests (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_requests_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_requests);


--
-- Name: traveler_rooms; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.traveler_rooms (
    operating_year integer DEFAULT 2019,
    CONSTRAINT traveler_rooms_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.traveler_rooms);


--
-- Name: travelers; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.travelers (
    operating_year integer DEFAULT 2019,
    CONSTRAINT travelers_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.travelers);


--
-- Name: user_event_registrations; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_event_registrations (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_event_registrations_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_event_registrations);


--
-- Name: user_marathon_registrations; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_marathon_registrations (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_marathon_registrations_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_marathon_registrations);


--
-- Name: user_messages; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_messages (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_messages_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_messages);


--
-- Name: user_overrides; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_overrides (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_overrides_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_overrides);


--
-- Name: user_transfer_expectations; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_transfer_expectations (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_transfer_expectations_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_transfer_expectations);


--
-- Name: user_travel_preparations; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_travel_preparations (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_travel_preparations_operating_year_check1 CHECK ((operating_year = 2019))
)
INHERITS (public.user_travel_preparations);


--
-- Name: user_uniform_orders; Type: TABLE; Schema: year_2019; Owner: -
--

CREATE TABLE year_2019.user_uniform_orders (
    operating_year integer DEFAULT 2019,
    CONSTRAINT user_uniform_orders_operating_year_check CHECK ((operating_year = 2019))
)
INHERITS (public.user_uniform_orders);


--
-- Name: competing_teams; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.competing_teams (
    operating_year integer DEFAULT 2020,
    CONSTRAINT competing_teams_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.competing_teams);


--
-- Name: competing_teams_travelers; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.competing_teams_travelers (
    operating_year integer DEFAULT 2020,
    CONSTRAINT competing_teams_travelers_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.competing_teams_travelers);


--
-- Name: flight_legs; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.flight_legs (
    operating_year integer DEFAULT 2020,
    CONSTRAINT flight_legs_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.flight_legs);


--
-- Name: flight_schedules; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.flight_schedules (
    operating_year integer DEFAULT 2020,
    CONSTRAINT flight_schedules_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.flight_schedules);


--
-- Name: flight_tickets; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.flight_tickets (
    operating_year integer DEFAULT 2020,
    CONSTRAINT flight_tickets_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.flight_tickets);


--
-- Name: mailings; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.mailings (
    operating_year integer DEFAULT 2020,
    CONSTRAINT mailings_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.mailings);


--
-- Name: meeting_registrations; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.meeting_registrations (
    operating_year integer DEFAULT 2020,
    CONSTRAINT meeting_registrations_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.meeting_registrations);


--
-- Name: meeting_video_views; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.meeting_video_views (
    operating_year integer DEFAULT 2020,
    CONSTRAINT meeting_video_views_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.meeting_video_views);


--
-- Name: payment_items; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.payment_items (
    operating_year integer DEFAULT 2020,
    CONSTRAINT payment_items_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.payment_items);


--
-- Name: payment_join_terms; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.payment_join_terms (
    operating_year integer DEFAULT 2020,
    CONSTRAINT payment_join_terms_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.payment_join_terms);


--
-- Name: payment_remittances; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.payment_remittances (
    operating_year integer DEFAULT 2020,
    CONSTRAINT payment_remittances_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.payment_remittances);


--
-- Name: payments; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.payments (
    operating_year integer DEFAULT 2020,
    CONSTRAINT payments_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.payments);


--
-- Name: sent_mails; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.sent_mails (
    operating_year integer DEFAULT 2020,
    CONSTRAINT sent_mails_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.sent_mails);


--
-- Name: staff_assignment_visits; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.staff_assignment_visits (
    operating_year integer DEFAULT 2020,
    CONSTRAINT staff_assignment_visits_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.staff_assignment_visits);


--
-- Name: staff_assignments; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.staff_assignments (
    operating_year integer DEFAULT 2020,
    CONSTRAINT staff_assignments_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.staff_assignments);


--
-- Name: student_lists; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.student_lists (
    operating_year integer DEFAULT 2020,
    CONSTRAINT student_lists_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.student_lists);


--
-- Name: teams; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.teams (
    operating_year integer DEFAULT 2020,
    CONSTRAINT teams_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.teams);


--
-- Name: traveler_buses; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_buses (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_buses_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_buses);


--
-- Name: traveler_buses_travelers; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_buses_travelers (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_buses_travelers_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_buses_travelers);


--
-- Name: traveler_credits; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_credits (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_credits_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_credits);


--
-- Name: traveler_debits; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_debits (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_debits_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_debits);


--
-- Name: traveler_offers; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_offers (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_offers_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_offers);


--
-- Name: traveler_requests; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_requests (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_requests_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_requests);


--
-- Name: traveler_rooms; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.traveler_rooms (
    operating_year integer DEFAULT 2020,
    CONSTRAINT traveler_rooms_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.traveler_rooms);


--
-- Name: travelers; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.travelers (
    operating_year integer DEFAULT 2020,
    CONSTRAINT travelers_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.travelers);


--
-- Name: user_event_registrations; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_event_registrations (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_event_registrations_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_event_registrations);


--
-- Name: user_marathon_registrations; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_marathon_registrations (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_marathon_registrations_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_marathon_registrations);


--
-- Name: user_messages; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_messages (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_messages_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_messages);


--
-- Name: user_overrides; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_overrides (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_overrides_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_overrides);


--
-- Name: user_transfer_expectations; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_transfer_expectations (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_transfer_expectations_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_transfer_expectations);


--
-- Name: user_travel_preparations; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_travel_preparations (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_travel_preparations_operating_year_check1 CHECK ((operating_year = 2020))
)
INHERITS (public.user_travel_preparations);


--
-- Name: user_uniform_orders; Type: TABLE; Schema: year_2020; Owner: -
--

CREATE TABLE year_2020.user_uniform_orders (
    operating_year integer DEFAULT 2020,
    CONSTRAINT user_uniform_orders_operating_year_check CHECK ((operating_year = 2020))
)
INHERITS (public.user_uniform_orders);


--
-- Name: logged_actions event_id; Type: DEFAULT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions ALTER COLUMN event_id SET DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass);


--
-- Name: logged_actions_view event_id; Type: DEFAULT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_view ALTER COLUMN event_id SET DEFAULT nextval('auditing.logged_actions_event_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: address_variants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_variants ALTER COLUMN id SET DEFAULT nextval('public.address_variants_id_seq'::regclass);


--
-- Name: addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses ALTER COLUMN id SET DEFAULT nextval('public.addresses_id_seq'::regclass);


--
-- Name: athletes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes ALTER COLUMN id SET DEFAULT nextval('public.athletes_id_seq'::regclass);


--
-- Name: athletes_sports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes_sports ALTER COLUMN id SET DEFAULT nextval('public.athletes_sports_id_seq'::regclass);


--
-- Name: better_record_attachment_validations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.better_record_attachment_validations ALTER COLUMN id SET DEFAULT nextval('public.better_record_attachment_validations_id_seq'::regclass);


--
-- Name: chat_room_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_room_messages ALTER COLUMN id SET DEFAULT nextval('public.chat_room_messages_id_seq'::regclass);


--
-- Name: coaches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches ALTER COLUMN id SET DEFAULT nextval('public.coaches_id_seq'::regclass);


--
-- Name: competing_teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competing_teams ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_id_seq'::regclass);


--
-- Name: competing_teams_travelers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competing_teams_travelers ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_travelers_id_seq'::regclass);


--
-- Name: event_result_static_files id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_result_static_files ALTER COLUMN id SET DEFAULT nextval('public.event_result_static_files_id_seq'::regclass);


--
-- Name: event_results id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_results ALTER COLUMN id SET DEFAULT nextval('public.event_results_id_seq'::regclass);


--
-- Name: flight_airports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_airports ALTER COLUMN id SET DEFAULT nextval('public.flight_airports_id_seq'::regclass);


--
-- Name: flight_legs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_legs ALTER COLUMN id SET DEFAULT nextval('public.flight_legs_id_seq'::regclass);


--
-- Name: flight_schedules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_schedules ALTER COLUMN id SET DEFAULT nextval('public.flight_schedules_id_seq'::regclass);


--
-- Name: flight_tickets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_tickets ALTER COLUMN id SET DEFAULT nextval('public.flight_tickets_id_seq'::regclass);


--
-- Name: fundraising_idea_images id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fundraising_idea_images ALTER COLUMN id SET DEFAULT nextval('public.fundraising_idea_images_id_seq'::regclass);


--
-- Name: fundraising_ideas id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fundraising_ideas ALTER COLUMN id SET DEFAULT nextval('public.fundraising_ideas_id_seq'::regclass);


--
-- Name: import_athletes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_athletes ALTER COLUMN id SET DEFAULT nextval('public.import_athletes_id_seq'::regclass);


--
-- Name: import_backups id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_backups ALTER COLUMN id SET DEFAULT nextval('public.import_backups_id_seq'::regclass);


--
-- Name: import_errors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_errors ALTER COLUMN id SET DEFAULT nextval('public.import_errors_id_seq'::regclass);


--
-- Name: import_matches id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_matches ALTER COLUMN id SET DEFAULT nextval('public.import_matches_id_seq'::regclass);


--
-- Name: interests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests ALTER COLUMN id SET DEFAULT nextval('public.interests_id_seq'::regclass);


--
-- Name: invite_rules id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_rules ALTER COLUMN id SET DEFAULT nextval('public.invite_rules_id_seq'::regclass);


--
-- Name: invite_stats id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_stats ALTER COLUMN id SET DEFAULT nextval('public.invite_stats_id_seq'::regclass);


--
-- Name: mailings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailings ALTER COLUMN id SET DEFAULT nextval('public.mailings_id_seq'::regclass);


--
-- Name: meeting_registrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_registrations ALTER COLUMN id SET DEFAULT nextval('public.meeting_registrations_id_seq'::regclass);


--
-- Name: meeting_video_views id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_video_views ALTER COLUMN id SET DEFAULT nextval('public.meeting_video_views_id_seq'::regclass);


--
-- Name: meeting_videos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_videos ALTER COLUMN id SET DEFAULT nextval('public.meeting_videos_id_seq'::regclass);


--
-- Name: meetings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings ALTER COLUMN id SET DEFAULT nextval('public.meetings_id_seq'::regclass);


--
-- Name: officials id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.officials ALTER COLUMN id SET DEFAULT nextval('public.officials_id_seq'::regclass);


--
-- Name: participants id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants ALTER COLUMN id SET DEFAULT nextval('public.participants_id_seq'::regclass);


--
-- Name: payment_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_items ALTER COLUMN id SET DEFAULT nextval('public.payment_items_id_seq'::regclass);


--
-- Name: payment_join_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_join_terms ALTER COLUMN id SET DEFAULT nextval('public.payment_join_terms_id_seq'::regclass);


--
-- Name: payment_remittances id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_remittances ALTER COLUMN id SET DEFAULT nextval('public.payment_remittances_id_seq'::regclass);


--
-- Name: payment_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_terms ALTER COLUMN id SET DEFAULT nextval('public.payment_terms_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: privacy_policies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policies ALTER COLUMN id SET DEFAULT nextval('public.privacy_policies_id_seq'::regclass);


--
-- Name: schools id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools ALTER COLUMN id SET DEFAULT nextval('public.schools_id_seq'::regclass);


--
-- Name: sent_mails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sent_mails ALTER COLUMN id SET DEFAULT nextval('public.sent_mails_id_seq'::regclass);


--
-- Name: shirt_order_items id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_items ALTER COLUMN id SET DEFAULT nextval('public.shirt_order_items_id_seq'::regclass);


--
-- Name: shirt_order_shipments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_shipments ALTER COLUMN id SET DEFAULT nextval('public.shirt_order_shipments_id_seq'::regclass);


--
-- Name: shirt_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_orders ALTER COLUMN id SET DEFAULT nextval('public.shirt_orders_id_seq'::regclass);


--
-- Name: sources id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources ALTER COLUMN id SET DEFAULT nextval('public.sources_id_seq'::regclass);


--
-- Name: sport_events id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_events ALTER COLUMN id SET DEFAULT nextval('public.sport_events_id_seq'::regclass);


--
-- Name: sport_infos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_infos ALTER COLUMN id SET DEFAULT nextval('public.sport_infos_id_seq'::regclass);


--
-- Name: sports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sports ALTER COLUMN id SET DEFAULT nextval('public.sports_id_seq'::regclass);


--
-- Name: staff_assignment_visits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_assignment_visits ALTER COLUMN id SET DEFAULT nextval('public.staff_assignment_visits_id_seq'::regclass);


--
-- Name: staff_assignments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_assignments ALTER COLUMN id SET DEFAULT nextval('public.staff_assignments_id_seq'::regclass);


--
-- Name: staff_clocks id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_clocks ALTER COLUMN id SET DEFAULT nextval('public.staff_clocks_id_seq'::regclass);


--
-- Name: staffs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staffs ALTER COLUMN id SET DEFAULT nextval('public.staffs_id_seq'::regclass);


--
-- Name: states id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states ALTER COLUMN id SET DEFAULT nextval('public.states_id_seq'::regclass);


--
-- Name: student_lists id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_lists ALTER COLUMN id SET DEFAULT nextval('public.student_lists_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: thank_you_ticket_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thank_you_ticket_terms ALTER COLUMN id SET DEFAULT nextval('public.thank_you_ticket_terms_id_seq'::regclass);


--
-- Name: traveler_base_debits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_base_debits ALTER COLUMN id SET DEFAULT nextval('public.traveler_base_debits_id_seq'::regclass);


--
-- Name: traveler_buses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_buses ALTER COLUMN id SET DEFAULT nextval('public.traveler_buses_id_seq'::regclass);


--
-- Name: traveler_credits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_credits ALTER COLUMN id SET DEFAULT nextval('public.traveler_credits_id_seq'::regclass);


--
-- Name: traveler_debits id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_debits ALTER COLUMN id SET DEFAULT nextval('public.traveler_debits_id_seq'::regclass);


--
-- Name: traveler_hotels id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_hotels ALTER COLUMN id SET DEFAULT nextval('public.traveler_hotels_id_seq'::regclass);


--
-- Name: traveler_offers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_offers ALTER COLUMN id SET DEFAULT nextval('public.traveler_offers_id_seq'::regclass);


--
-- Name: traveler_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_requests ALTER COLUMN id SET DEFAULT nextval('public.traveler_requests_id_seq'::regclass);


--
-- Name: traveler_rooms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_rooms ALTER COLUMN id SET DEFAULT nextval('public.traveler_rooms_id_seq'::regclass);


--
-- Name: travelers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travelers ALTER COLUMN id SET DEFAULT nextval('public.travelers_id_seq'::regclass);


--
-- Name: unsubscribers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribers ALTER COLUMN id SET DEFAULT nextval('public.unsubscribers_id_seq'::regclass);


--
-- Name: user_ambassadors id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ambassadors ALTER COLUMN id SET DEFAULT nextval('public.user_ambassadors_id_seq'::regclass);


--
-- Name: user_event_registrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_event_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_event_registrations_id_seq'::regclass);


--
-- Name: user_interest_histories id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interest_histories ALTER COLUMN id SET DEFAULT nextval('public.user_interest_histories_id_seq'::regclass);


--
-- Name: user_marathon_registrations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_marathon_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_marathon_registrations_id_seq'::regclass);


--
-- Name: user_messages id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_messages ALTER COLUMN id SET DEFAULT nextval('public.user_messages_id_seq1'::regclass);


--
-- Name: user_nationalities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_nationalities ALTER COLUMN id SET DEFAULT nextval('public.user_nationalities_id_seq'::regclass);


--
-- Name: user_overrides id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_overrides ALTER COLUMN id SET DEFAULT nextval('public.user_overrides_id_seq'::regclass);


--
-- Name: user_passport_authorities id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passport_authorities ALTER COLUMN id SET DEFAULT nextval('public.user_passport_authorities_id_seq'::regclass);


--
-- Name: user_passports id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passports ALTER COLUMN id SET DEFAULT nextval('public.user_passports_id_seq'::regclass);


--
-- Name: user_refund_requests id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_refund_requests ALTER COLUMN id SET DEFAULT nextval('public.user_refund_requests_id_seq'::regclass);


--
-- Name: user_relations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relations ALTER COLUMN id SET DEFAULT nextval('public.user_relations_id_seq'::regclass);


--
-- Name: user_transfer_expectations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_transfer_expectations ALTER COLUMN id SET DEFAULT nextval('public.user_transfer_expectations_id_seq'::regclass);


--
-- Name: user_travel_preparations id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_travel_preparations ALTER COLUMN id SET DEFAULT nextval('public.user_travel_preparations_id_seq1'::regclass);


--
-- Name: user_uniform_orders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_uniform_orders ALTER COLUMN id SET DEFAULT nextval('public.user_uniform_orders_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: view_trackers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_trackers ALTER COLUMN id SET DEFAULT nextval('public.view_trackers_id_seq'::regclass);


--
-- Name: competing_teams id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_id_seq'::regclass);


--
-- Name: competing_teams created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: competing_teams updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: competing_teams_travelers id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams_travelers ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_travelers_id_seq'::regclass);


--
-- Name: flight_legs id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs ALTER COLUMN id SET DEFAULT nextval('public.flight_legs_id_seq'::regclass);


--
-- Name: flight_legs overnight; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs ALTER COLUMN overnight SET DEFAULT false;


--
-- Name: flight_legs is_subsidiary; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs ALTER COLUMN is_subsidiary SET DEFAULT false;


--
-- Name: flight_legs created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_legs updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: flight_schedules id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules ALTER COLUMN id SET DEFAULT nextval('public.flight_schedules_id_seq'::regclass);


--
-- Name: flight_schedules seats_reserved; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules ALTER COLUMN seats_reserved SET DEFAULT 0;


--
-- Name: flight_schedules names_assigned; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules ALTER COLUMN names_assigned SET DEFAULT 0;


--
-- Name: flight_schedules created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_schedules updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: flight_tickets id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN id SET DEFAULT nextval('public.flight_tickets_id_seq'::regclass);


--
-- Name: flight_tickets ticketed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN ticketed SET DEFAULT false;


--
-- Name: flight_tickets required; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN required SET DEFAULT false;


--
-- Name: flight_tickets is_checked_in; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN is_checked_in SET DEFAULT false;


--
-- Name: flight_tickets created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_tickets updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: mailings id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN id SET DEFAULT nextval('public.mailings_id_seq'::regclass);


--
-- Name: mailings explicit; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN explicit SET DEFAULT false;


--
-- Name: mailings printed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN printed SET DEFAULT false;


--
-- Name: mailings is_home; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN is_home SET DEFAULT false;


--
-- Name: mailings is_foreign; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN is_foreign SET DEFAULT false;


--
-- Name: mailings auto; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN auto SET DEFAULT false;


--
-- Name: mailings failed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN failed SET DEFAULT false;


--
-- Name: mailings country; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN country SET DEFAULT 'USA'::text;


--
-- Name: mailings created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: mailings updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: meeting_registrations id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations ALTER COLUMN id SET DEFAULT nextval('public.meeting_registrations_id_seq'::regclass);


--
-- Name: meeting_registrations attended; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations ALTER COLUMN attended SET DEFAULT false;


--
-- Name: meeting_registrations duration; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations ALTER COLUMN duration SET DEFAULT '00:00:00'::interval;


--
-- Name: meeting_registrations created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: meeting_registrations updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: meeting_video_views id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN id SET DEFAULT nextval('public.meeting_video_views_id_seq'::regclass);


--
-- Name: meeting_video_views watched; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN watched SET DEFAULT false;


--
-- Name: meeting_video_views duration; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN duration SET DEFAULT '00:00:00'::interval;


--
-- Name: meeting_video_views questions; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN questions SET DEFAULT '{}'::text[];


--
-- Name: meeting_video_views gave_offer; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN gave_offer SET DEFAULT false;


--
-- Name: meeting_video_views created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: meeting_video_views updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_items id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN id SET DEFAULT nextval('public.payment_items_id_seq'::regclass);


--
-- Name: payment_items amount; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN amount SET DEFAULT 0;


--
-- Name: payment_items price; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN price SET DEFAULT 0;


--
-- Name: payment_items quantity; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN quantity SET DEFAULT 1;


--
-- Name: payment_items name; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN name SET DEFAULT 'Account Payment'::text;


--
-- Name: payment_items created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_items updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_join_terms id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms ALTER COLUMN id SET DEFAULT nextval('public.payment_join_terms_id_seq'::regclass);


--
-- Name: payment_join_terms created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_join_terms updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_remittances id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances ALTER COLUMN id SET DEFAULT nextval('public.payment_remittances_id_seq'::regclass);


--
-- Name: payment_remittances recorded; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances ALTER COLUMN recorded SET DEFAULT false;


--
-- Name: payment_remittances reconciled; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances ALTER COLUMN reconciled SET DEFAULT false;


--
-- Name: payment_remittances created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_remittances updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payments id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: payments gateway_type; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN gateway_type SET DEFAULT 'braintree'::text;


--
-- Name: payments successful; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN successful SET DEFAULT false;


--
-- Name: payments category; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN category SET DEFAULT 'account'::text;


--
-- Name: payments remit_number; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN remit_number SET DEFAULT ((now())::date || '-CC'::text);


--
-- Name: payments billing; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN billing SET DEFAULT '{}'::jsonb;


--
-- Name: payments processor; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN processor SET DEFAULT '{}'::jsonb;


--
-- Name: payments settlement; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN settlement SET DEFAULT '{}'::jsonb;


--
-- Name: payments gateway; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN gateway SET DEFAULT '{}'::jsonb;


--
-- Name: payments risk; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN risk SET DEFAULT '{}'::jsonb;


--
-- Name: payments anonymous; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN anonymous SET DEFAULT false;


--
-- Name: payments created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payments updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: sent_mails id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.sent_mails ALTER COLUMN id SET DEFAULT nextval('public.sent_mails_id_seq'::regclass);


--
-- Name: sent_mails created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.sent_mails ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignment_visits id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignment_visits ALTER COLUMN id SET DEFAULT nextval('public.staff_assignment_visits_id_seq'::regclass);


--
-- Name: staff_assignment_visits created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignment_visits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignment_visits updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignment_visits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: staff_assignments id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN id SET DEFAULT nextval('public.staff_assignments_id_seq'::regclass);


--
-- Name: staff_assignments reason; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN reason SET DEFAULT 'Follow Up'::text;


--
-- Name: staff_assignments completed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN completed SET DEFAULT false;


--
-- Name: staff_assignments unneeded; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN unneeded SET DEFAULT false;


--
-- Name: staff_assignments reviewed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN reviewed SET DEFAULT false;


--
-- Name: staff_assignments locked; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN locked SET DEFAULT false;


--
-- Name: staff_assignments created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignments updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: student_lists id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.student_lists ALTER COLUMN id SET DEFAULT nextval('public.student_lists_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: teams created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: teams updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_buses id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses ALTER COLUMN id SET DEFAULT nextval('public.traveler_buses_id_seq'::regclass);


--
-- Name: traveler_buses capacity; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses ALTER COLUMN capacity SET DEFAULT 0;


--
-- Name: traveler_buses created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_buses updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_credits id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits ALTER COLUMN id SET DEFAULT nextval('public.traveler_credits_id_seq'::regclass);


--
-- Name: traveler_credits created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_credits updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_debits id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits ALTER COLUMN id SET DEFAULT nextval('public.traveler_debits_id_seq'::regclass);


--
-- Name: traveler_debits created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_debits updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_offers id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers ALTER COLUMN id SET DEFAULT nextval('public.traveler_offers_id_seq'::regclass);


--
-- Name: traveler_offers rules; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers ALTER COLUMN rules SET DEFAULT '{}'::text[];


--
-- Name: traveler_offers created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_offers updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_requests id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_requests ALTER COLUMN id SET DEFAULT nextval('public.traveler_requests_id_seq'::regclass);


--
-- Name: traveler_requests created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_requests ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_requests updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_requests ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_rooms id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms ALTER COLUMN id SET DEFAULT nextval('public.traveler_rooms_id_seq'::regclass);


--
-- Name: traveler_rooms created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_rooms updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: travelers id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN id SET DEFAULT nextval('public.travelers_id_seq'::regclass);


--
-- Name: travelers has_ground_transportation; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN has_ground_transportation SET DEFAULT true;


--
-- Name: travelers has_lodging; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN has_lodging SET DEFAULT true;


--
-- Name: travelers has_gbr; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN has_gbr SET DEFAULT false;


--
-- Name: travelers own_flights; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN own_flights SET DEFAULT false;


--
-- Name: travelers created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: travelers updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_event_registrations id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_event_registrations_id_seq'::regclass);


--
-- Name: user_event_registrations event_100_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_100_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_100_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_100_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_200_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_200_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_200_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_200_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_400_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_400_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_400_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_400_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_800_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_800_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_800_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_800_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_1500_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_1500_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_1500_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_1500_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_3000_m; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_3000_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_3000_m_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_3000_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_90_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_90_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_90_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_90_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_100_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_100_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_100_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_100_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_110_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_110_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_110_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_110_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_200_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_200_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_200_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_200_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_300_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_300_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_300_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_300_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_400_m_hurdles; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_400_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_400_m_hurdles_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_400_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_2000_m_steeple; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_2000_m_steeple SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_2000_m_steeple_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_2000_m_steeple_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_long_jump; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_long_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_long_jump_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_long_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_triple_jump; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_triple_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_triple_jump_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_triple_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_high_jump; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_high_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_high_jump_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_high_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_pole_vault; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_pole_vault SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_pole_vault_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_pole_vault_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_shot_put; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_shot_put SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_shot_put_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_shot_put_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_discus; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_discus SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_discus_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_discus_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_javelin; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_javelin SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_javelin_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_javelin_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_hammer; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_hammer SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_hammer_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_hammer_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_3000_m_walk; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_3000_m_walk SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_3000_m_walk_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_3000_m_walk_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_5000_m_walk; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_5000_m_walk SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_5000_m_walk_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN event_5000_m_walk_count SET DEFAULT 0;


--
-- Name: user_event_registrations created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_event_registrations updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_marathon_registrations id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_marathon_registrations_id_seq'::regclass);


--
-- Name: user_marathon_registrations email; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations ALTER COLUMN email SET DEFAULT 'gcm-registrations@downundersports.com'::text;


--
-- Name: user_marathon_registrations created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_marathon_registrations updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_messages id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages ALTER COLUMN id SET DEFAULT nextval('public.user_messages_id_seq1'::regclass);


--
-- Name: user_messages reason; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages ALTER COLUMN reason SET DEFAULT 'other'::text;


--
-- Name: user_messages reviewed; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages ALTER COLUMN reviewed SET DEFAULT false;


--
-- Name: user_messages created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_messages updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_overrides id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_overrides ALTER COLUMN id SET DEFAULT nextval('public.user_overrides_id_seq'::regclass);


--
-- Name: user_overrides created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_overrides ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_overrides updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_overrides ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_transfer_expectations id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN id SET DEFAULT nextval('public.user_transfer_expectations_id_seq'::regclass);


--
-- Name: user_transfer_expectations can_transfer; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN can_transfer SET DEFAULT 'U'::public.three_state;


--
-- Name: user_transfer_expectations can_compete; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN can_compete SET DEFAULT 'U'::public.three_state;


--
-- Name: user_transfer_expectations offer; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN offer SET DEFAULT '"{}"'::jsonb;


--
-- Name: user_transfer_expectations created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_transfer_expectations updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_travel_preparations id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN id SET DEFAULT nextval('public.user_travel_preparations_id_seq1'::regclass);


--
-- Name: user_travel_preparations applications; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN applications SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations calls; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN calls SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations confirmations; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN confirmations SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations deadlines; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN deadlines SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations emails; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN emails SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations followups; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN followups SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations items_received; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN items_received SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations extra_eta_processing; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN extra_eta_processing SET DEFAULT false;


--
-- Name: user_travel_preparations has_multiple_citizenships; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN has_multiple_citizenships SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations citizenships_array; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN citizenships_array SET DEFAULT '{}'::text[];


--
-- Name: user_travel_preparations has_aliases; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN has_aliases SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations aliases_array; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN aliases_array SET DEFAULT '{}'::character varying[];


--
-- Name: user_travel_preparations has_convictions; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN has_convictions SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations convictions_array; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN convictions_array SET DEFAULT '{}'::text[];


--
-- Name: user_travel_preparations created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_travel_preparations updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_uniform_orders id; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN id SET DEFAULT nextval('public.user_uniform_orders_id_seq'::regclass);


--
-- Name: user_uniform_orders is_reorder; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN is_reorder SET DEFAULT false;


--
-- Name: user_uniform_orders jersey_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN jersey_count SET DEFAULT 1;


--
-- Name: user_uniform_orders shorts_count; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN shorts_count SET DEFAULT 1;


--
-- Name: user_uniform_orders shipping; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN shipping SET DEFAULT '{}'::jsonb;


--
-- Name: user_uniform_orders created_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_uniform_orders updated_at; Type: DEFAULT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: competing_teams id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_id_seq'::regclass);


--
-- Name: competing_teams created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: competing_teams updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: competing_teams_travelers id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams_travelers ALTER COLUMN id SET DEFAULT nextval('public.competing_teams_travelers_id_seq'::regclass);


--
-- Name: flight_legs id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs ALTER COLUMN id SET DEFAULT nextval('public.flight_legs_id_seq'::regclass);


--
-- Name: flight_legs overnight; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs ALTER COLUMN overnight SET DEFAULT false;


--
-- Name: flight_legs is_subsidiary; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs ALTER COLUMN is_subsidiary SET DEFAULT false;


--
-- Name: flight_legs created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_legs updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: flight_schedules id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules ALTER COLUMN id SET DEFAULT nextval('public.flight_schedules_id_seq'::regclass);


--
-- Name: flight_schedules seats_reserved; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules ALTER COLUMN seats_reserved SET DEFAULT 0;


--
-- Name: flight_schedules names_assigned; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules ALTER COLUMN names_assigned SET DEFAULT 0;


--
-- Name: flight_schedules created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_schedules updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: flight_tickets id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN id SET DEFAULT nextval('public.flight_tickets_id_seq'::regclass);


--
-- Name: flight_tickets ticketed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN ticketed SET DEFAULT false;


--
-- Name: flight_tickets required; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN required SET DEFAULT false;


--
-- Name: flight_tickets is_checked_in; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN is_checked_in SET DEFAULT false;


--
-- Name: flight_tickets created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: flight_tickets updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: mailings id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN id SET DEFAULT nextval('public.mailings_id_seq'::regclass);


--
-- Name: mailings explicit; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN explicit SET DEFAULT false;


--
-- Name: mailings printed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN printed SET DEFAULT false;


--
-- Name: mailings is_home; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN is_home SET DEFAULT false;


--
-- Name: mailings is_foreign; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN is_foreign SET DEFAULT false;


--
-- Name: mailings auto; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN auto SET DEFAULT false;


--
-- Name: mailings failed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN failed SET DEFAULT false;


--
-- Name: mailings country; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN country SET DEFAULT 'USA'::text;


--
-- Name: mailings created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: mailings updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: meeting_registrations id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations ALTER COLUMN id SET DEFAULT nextval('public.meeting_registrations_id_seq'::regclass);


--
-- Name: meeting_registrations attended; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations ALTER COLUMN attended SET DEFAULT false;


--
-- Name: meeting_registrations duration; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations ALTER COLUMN duration SET DEFAULT '00:00:00'::interval;


--
-- Name: meeting_registrations created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: meeting_registrations updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: meeting_video_views id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN id SET DEFAULT nextval('public.meeting_video_views_id_seq'::regclass);


--
-- Name: meeting_video_views watched; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN watched SET DEFAULT false;


--
-- Name: meeting_video_views duration; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN duration SET DEFAULT '00:00:00'::interval;


--
-- Name: meeting_video_views questions; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN questions SET DEFAULT '{}'::text[];


--
-- Name: meeting_video_views gave_offer; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN gave_offer SET DEFAULT false;


--
-- Name: meeting_video_views created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: meeting_video_views updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_items id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN id SET DEFAULT nextval('public.payment_items_id_seq'::regclass);


--
-- Name: payment_items amount; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN amount SET DEFAULT 0;


--
-- Name: payment_items price; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN price SET DEFAULT 0;


--
-- Name: payment_items quantity; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN quantity SET DEFAULT 1;


--
-- Name: payment_items name; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN name SET DEFAULT 'Account Payment'::text;


--
-- Name: payment_items created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_items updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_join_terms id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms ALTER COLUMN id SET DEFAULT nextval('public.payment_join_terms_id_seq'::regclass);


--
-- Name: payment_join_terms created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_join_terms updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payment_remittances id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances ALTER COLUMN id SET DEFAULT nextval('public.payment_remittances_id_seq'::regclass);


--
-- Name: payment_remittances recorded; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances ALTER COLUMN recorded SET DEFAULT false;


--
-- Name: payment_remittances reconciled; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances ALTER COLUMN reconciled SET DEFAULT false;


--
-- Name: payment_remittances created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payment_remittances updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: payments id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: payments gateway_type; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN gateway_type SET DEFAULT 'braintree'::text;


--
-- Name: payments successful; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN successful SET DEFAULT false;


--
-- Name: payments category; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN category SET DEFAULT 'account'::text;


--
-- Name: payments remit_number; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN remit_number SET DEFAULT ((now())::date || '-CC'::text);


--
-- Name: payments billing; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN billing SET DEFAULT '{}'::jsonb;


--
-- Name: payments processor; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN processor SET DEFAULT '{}'::jsonb;


--
-- Name: payments settlement; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN settlement SET DEFAULT '{}'::jsonb;


--
-- Name: payments gateway; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN gateway SET DEFAULT '{}'::jsonb;


--
-- Name: payments risk; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN risk SET DEFAULT '{}'::jsonb;


--
-- Name: payments anonymous; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN anonymous SET DEFAULT false;


--
-- Name: payments created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: payments updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: sent_mails id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.sent_mails ALTER COLUMN id SET DEFAULT nextval('public.sent_mails_id_seq'::regclass);


--
-- Name: sent_mails created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.sent_mails ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignment_visits id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignment_visits ALTER COLUMN id SET DEFAULT nextval('public.staff_assignment_visits_id_seq'::regclass);


--
-- Name: staff_assignment_visits created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignment_visits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignment_visits updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignment_visits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: staff_assignments id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN id SET DEFAULT nextval('public.staff_assignments_id_seq'::regclass);


--
-- Name: staff_assignments reason; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN reason SET DEFAULT 'Follow Up'::text;


--
-- Name: staff_assignments completed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN completed SET DEFAULT false;


--
-- Name: staff_assignments unneeded; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN unneeded SET DEFAULT false;


--
-- Name: staff_assignments reviewed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN reviewed SET DEFAULT false;


--
-- Name: staff_assignments locked; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN locked SET DEFAULT false;


--
-- Name: staff_assignments created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: staff_assignments updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: student_lists id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.student_lists ALTER COLUMN id SET DEFAULT nextval('public.student_lists_id_seq'::regclass);


--
-- Name: teams id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams ALTER COLUMN id SET DEFAULT nextval('public.teams_id_seq'::regclass);


--
-- Name: teams created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: teams updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_buses id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses ALTER COLUMN id SET DEFAULT nextval('public.traveler_buses_id_seq'::regclass);


--
-- Name: traveler_buses capacity; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses ALTER COLUMN capacity SET DEFAULT 0;


--
-- Name: traveler_buses created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_buses updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_credits id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits ALTER COLUMN id SET DEFAULT nextval('public.traveler_credits_id_seq'::regclass);


--
-- Name: traveler_credits created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_credits updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_debits id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits ALTER COLUMN id SET DEFAULT nextval('public.traveler_debits_id_seq'::regclass);


--
-- Name: traveler_debits created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_debits updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_offers id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers ALTER COLUMN id SET DEFAULT nextval('public.traveler_offers_id_seq'::regclass);


--
-- Name: traveler_offers rules; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers ALTER COLUMN rules SET DEFAULT '{}'::text[];


--
-- Name: traveler_offers created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_offers updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_requests id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_requests ALTER COLUMN id SET DEFAULT nextval('public.traveler_requests_id_seq'::regclass);


--
-- Name: traveler_requests created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_requests ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_requests updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_requests ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: traveler_rooms id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms ALTER COLUMN id SET DEFAULT nextval('public.traveler_rooms_id_seq'::regclass);


--
-- Name: traveler_rooms created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: traveler_rooms updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: travelers id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN id SET DEFAULT nextval('public.travelers_id_seq'::regclass);


--
-- Name: travelers has_ground_transportation; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN has_ground_transportation SET DEFAULT true;


--
-- Name: travelers has_lodging; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN has_lodging SET DEFAULT true;


--
-- Name: travelers has_gbr; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN has_gbr SET DEFAULT false;


--
-- Name: travelers own_flights; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN own_flights SET DEFAULT false;


--
-- Name: travelers created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: travelers updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_event_registrations id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_event_registrations_id_seq'::regclass);


--
-- Name: user_event_registrations event_100_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_100_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_100_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_100_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_200_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_200_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_200_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_200_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_400_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_400_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_400_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_400_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_800_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_800_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_800_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_800_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_1500_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_1500_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_1500_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_1500_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_3000_m; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_3000_m SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_3000_m_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_3000_m_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_90_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_90_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_90_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_90_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_100_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_100_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_100_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_100_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_110_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_110_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_110_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_110_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_200_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_200_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_200_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_200_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_300_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_300_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_300_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_300_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_400_m_hurdles; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_400_m_hurdles SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_400_m_hurdles_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_400_m_hurdles_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_2000_m_steeple; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_2000_m_steeple SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_2000_m_steeple_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_2000_m_steeple_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_long_jump; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_long_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_long_jump_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_long_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_triple_jump; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_triple_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_triple_jump_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_triple_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_high_jump; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_high_jump SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_high_jump_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_high_jump_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_pole_vault; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_pole_vault SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_pole_vault_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_pole_vault_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_shot_put; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_shot_put SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_shot_put_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_shot_put_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_discus; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_discus SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_discus_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_discus_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_javelin; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_javelin SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_javelin_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_javelin_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_hammer; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_hammer SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_hammer_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_hammer_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_3000_m_walk; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_3000_m_walk SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_3000_m_walk_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_3000_m_walk_count SET DEFAULT 0;


--
-- Name: user_event_registrations event_5000_m_walk; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_5000_m_walk SET DEFAULT '{}'::text[];


--
-- Name: user_event_registrations event_5000_m_walk_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN event_5000_m_walk_count SET DEFAULT 0;


--
-- Name: user_event_registrations created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_event_registrations updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_marathon_registrations id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations ALTER COLUMN id SET DEFAULT nextval('public.user_marathon_registrations_id_seq'::regclass);


--
-- Name: user_marathon_registrations email; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations ALTER COLUMN email SET DEFAULT 'gcm-registrations@downundersports.com'::text;


--
-- Name: user_marathon_registrations created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_marathon_registrations updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_messages id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages ALTER COLUMN id SET DEFAULT nextval('public.user_messages_id_seq1'::regclass);


--
-- Name: user_messages reason; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages ALTER COLUMN reason SET DEFAULT 'other'::text;


--
-- Name: user_messages reviewed; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages ALTER COLUMN reviewed SET DEFAULT false;


--
-- Name: user_messages created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_messages updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_overrides id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_overrides ALTER COLUMN id SET DEFAULT nextval('public.user_overrides_id_seq'::regclass);


--
-- Name: user_overrides created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_overrides ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_overrides updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_overrides ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_transfer_expectations id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN id SET DEFAULT nextval('public.user_transfer_expectations_id_seq'::regclass);


--
-- Name: user_transfer_expectations can_transfer; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN can_transfer SET DEFAULT 'U'::public.three_state;


--
-- Name: user_transfer_expectations can_compete; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN can_compete SET DEFAULT 'U'::public.three_state;


--
-- Name: user_transfer_expectations offer; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN offer SET DEFAULT '"{}"'::jsonb;


--
-- Name: user_transfer_expectations created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_transfer_expectations updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_travel_preparations id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN id SET DEFAULT nextval('public.user_travel_preparations_id_seq1'::regclass);


--
-- Name: user_travel_preparations applications; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN applications SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations calls; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN calls SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations confirmations; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN confirmations SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations deadlines; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN deadlines SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations emails; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN emails SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations followups; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN followups SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations items_received; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN items_received SET DEFAULT '{}'::jsonb;


--
-- Name: user_travel_preparations extra_eta_processing; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN extra_eta_processing SET DEFAULT false;


--
-- Name: user_travel_preparations has_multiple_citizenships; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN has_multiple_citizenships SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations citizenships_array; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN citizenships_array SET DEFAULT '{}'::text[];


--
-- Name: user_travel_preparations has_aliases; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN has_aliases SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations aliases_array; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN aliases_array SET DEFAULT '{}'::character varying[];


--
-- Name: user_travel_preparations has_convictions; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN has_convictions SET DEFAULT 'U'::public.three_state;


--
-- Name: user_travel_preparations convictions_array; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN convictions_array SET DEFAULT '{}'::text[];


--
-- Name: user_travel_preparations created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_travel_preparations updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: user_uniform_orders id; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN id SET DEFAULT nextval('public.user_uniform_orders_id_seq'::regclass);


--
-- Name: user_uniform_orders is_reorder; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN is_reorder SET DEFAULT false;


--
-- Name: user_uniform_orders jersey_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN jersey_count SET DEFAULT 1;


--
-- Name: user_uniform_orders shorts_count; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN shorts_count SET DEFAULT 1;


--
-- Name: user_uniform_orders shipping; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN shipping SET DEFAULT '{}'::jsonb;


--
-- Name: user_uniform_orders created_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN created_at SET DEFAULT now();


--
-- Name: user_uniform_orders updated_at; Type: DEFAULT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders ALTER COLUMN updated_at SET DEFAULT now();


--
-- Name: logged_actions_active_storage_attachments logged_actions_active_storage_attachments_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_active_storage_attachments
    ADD CONSTRAINT logged_actions_active_storage_attachments_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_active_storage_blobs logged_actions_active_storage_blobs_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_active_storage_blobs
    ADD CONSTRAINT logged_actions_active_storage_blobs_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_addresses logged_actions_addresses_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_addresses
    ADD CONSTRAINT logged_actions_addresses_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_athletes logged_actions_athletes_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_athletes
    ADD CONSTRAINT logged_actions_athletes_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_athletes_sports logged_actions_athletes_sports_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_athletes_sports
    ADD CONSTRAINT logged_actions_athletes_sports_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_coaches logged_actions_coaches_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_coaches
    ADD CONSTRAINT logged_actions_coaches_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_competing_teams logged_actions_competing_teams_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_competing_teams
    ADD CONSTRAINT logged_actions_competing_teams_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_competing_teams_travelers logged_actions_competing_teams_travelers_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_competing_teams_travelers
    ADD CONSTRAINT logged_actions_competing_teams_travelers_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_event_result_static_files logged_actions_event_result_static_files_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_event_result_static_files
    ADD CONSTRAINT logged_actions_event_result_static_files_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_event_results logged_actions_event_results_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_event_results
    ADD CONSTRAINT logged_actions_event_results_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_flight_airports logged_actions_flight_airports_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_flight_airports
    ADD CONSTRAINT logged_actions_flight_airports_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_flight_legs logged_actions_flight_legs_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_flight_legs
    ADD CONSTRAINT logged_actions_flight_legs_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_flight_schedules logged_actions_flight_schedules_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_flight_schedules
    ADD CONSTRAINT logged_actions_flight_schedules_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_flight_tickets logged_actions_flight_tickets_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_flight_tickets
    ADD CONSTRAINT logged_actions_flight_tickets_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_mailings logged_actions_mailings_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_mailings
    ADD CONSTRAINT logged_actions_mailings_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_meeting_registrations logged_actions_meeting_registrations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_meeting_registrations
    ADD CONSTRAINT logged_actions_meeting_registrations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_meeting_video_views logged_actions_meeting_video_views_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_meeting_video_views
    ADD CONSTRAINT logged_actions_meeting_video_views_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_meeting_videos logged_actions_meeting_videos_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_meeting_videos
    ADD CONSTRAINT logged_actions_meeting_videos_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_meetings logged_actions_meetings_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_meetings
    ADD CONSTRAINT logged_actions_meetings_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_officials logged_actions_officials_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_officials
    ADD CONSTRAINT logged_actions_officials_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_payment_items logged_actions_payment_items_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_payment_items
    ADD CONSTRAINT logged_actions_payment_items_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_payment_remittances logged_actions_payment_remittances_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_payment_remittances
    ADD CONSTRAINT logged_actions_payment_remittances_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_payments logged_actions_payments_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_payments
    ADD CONSTRAINT logged_actions_payments_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions logged_actions_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions
    ADD CONSTRAINT logged_actions_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_schools logged_actions_schools_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_schools
    ADD CONSTRAINT logged_actions_schools_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_sent_mails logged_actions_sent_mails_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_sent_mails
    ADD CONSTRAINT logged_actions_sent_mails_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_shirt_order_items logged_actions_shirt_order_items_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_shirt_order_items
    ADD CONSTRAINT logged_actions_shirt_order_items_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_shirt_order_shipments logged_actions_shirt_order_shipments_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_shirt_order_shipments
    ADD CONSTRAINT logged_actions_shirt_order_shipments_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_shirt_orders logged_actions_shirt_orders_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_shirt_orders
    ADD CONSTRAINT logged_actions_shirt_orders_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_sources logged_actions_sources_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_sources
    ADD CONSTRAINT logged_actions_sources_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_sports logged_actions_sports_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_sports
    ADD CONSTRAINT logged_actions_sports_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_staff_assignment_visits logged_actions_staff_assignment_visits_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_staff_assignment_visits
    ADD CONSTRAINT logged_actions_staff_assignment_visits_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_staff_assignments logged_actions_staff_assignments_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_staff_assignments
    ADD CONSTRAINT logged_actions_staff_assignments_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_staffs logged_actions_staffs_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_staffs
    ADD CONSTRAINT logged_actions_staffs_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_states logged_actions_states_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_states
    ADD CONSTRAINT logged_actions_states_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_student_lists logged_actions_student_lists_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_student_lists
    ADD CONSTRAINT logged_actions_student_lists_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_teams logged_actions_teams_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_teams
    ADD CONSTRAINT logged_actions_teams_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_base_debits logged_actions_traveler_base_debits_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_base_debits
    ADD CONSTRAINT logged_actions_traveler_base_debits_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_buses logged_actions_traveler_buses_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_buses
    ADD CONSTRAINT logged_actions_traveler_buses_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_buses_travelers logged_actions_traveler_buses_travelers_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_buses_travelers
    ADD CONSTRAINT logged_actions_traveler_buses_travelers_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_credits logged_actions_traveler_credits_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_credits
    ADD CONSTRAINT logged_actions_traveler_credits_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_debits logged_actions_traveler_debits_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_debits
    ADD CONSTRAINT logged_actions_traveler_debits_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_hotels logged_actions_traveler_hotels_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_hotels
    ADD CONSTRAINT logged_actions_traveler_hotels_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_offers logged_actions_traveler_offers_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_offers
    ADD CONSTRAINT logged_actions_traveler_offers_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_traveler_rooms logged_actions_traveler_rooms_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_traveler_rooms
    ADD CONSTRAINT logged_actions_traveler_rooms_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_travelers logged_actions_travelers_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_travelers
    ADD CONSTRAINT logged_actions_travelers_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_ambassadors logged_actions_user_ambassadors_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_ambassadors
    ADD CONSTRAINT logged_actions_user_ambassadors_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_event_registrations logged_actions_user_event_registrations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_event_registrations
    ADD CONSTRAINT logged_actions_user_event_registrations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_marathon_registrations logged_actions_user_marathon_registrations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_marathon_registrations
    ADD CONSTRAINT logged_actions_user_marathon_registrations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_messages logged_actions_user_messages_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_messages
    ADD CONSTRAINT logged_actions_user_messages_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_overrides logged_actions_user_overrides_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_overrides
    ADD CONSTRAINT logged_actions_user_overrides_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_relations logged_actions_user_relations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_relations
    ADD CONSTRAINT logged_actions_user_relations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_transfer_expectations logged_actions_user_transfer_expectations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_transfer_expectations
    ADD CONSTRAINT logged_actions_user_transfer_expectations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_travel_preparations logged_actions_user_travel_preparations_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_travel_preparations
    ADD CONSTRAINT logged_actions_user_travel_preparations_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_user_uniform_orders logged_actions_user_uniform_orders_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_user_uniform_orders
    ADD CONSTRAINT logged_actions_user_uniform_orders_pkey PRIMARY KEY (event_id);


--
-- Name: logged_actions_users logged_actions_users_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.logged_actions_users
    ADD CONSTRAINT logged_actions_users_pkey PRIMARY KEY (event_id);


--
-- Name: table_sizes table_sizes_pkey; Type: CONSTRAINT; Schema: auditing; Owner: -
--

ALTER TABLE ONLY auditing.table_sizes
    ADD CONSTRAINT table_sizes_pkey PRIMARY KEY (oid);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: address_variants address_variants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_variants
    ADD CONSTRAINT address_variants_pkey PRIMARY KEY (id);


--
-- Name: addresses addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT addresses_pkey PRIMARY KEY (id);


--
-- Name: athletes athletes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT athletes_pkey PRIMARY KEY (id);


--
-- Name: athletes_sports athletes_sports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes_sports
    ADD CONSTRAINT athletes_sports_pkey PRIMARY KEY (id);


--
-- Name: better_record_attachment_validations better_record_attachment_validations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.better_record_attachment_validations
    ADD CONSTRAINT better_record_attachment_validations_pkey PRIMARY KEY (id);


--
-- Name: chat_room_messages chat_room_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_room_messages
    ADD CONSTRAINT chat_room_messages_pkey PRIMARY KEY (id);


--
-- Name: chat_rooms chat_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_rooms
    ADD CONSTRAINT chat_rooms_pkey PRIMARY KEY (id);


--
-- Name: coaches coaches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT coaches_pkey PRIMARY KEY (id);


--
-- Name: competing_teams competing_teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competing_teams
    ADD CONSTRAINT competing_teams_pkey PRIMARY KEY (id);


--
-- Name: competing_teams_travelers competing_teams_travelers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competing_teams_travelers
    ADD CONSTRAINT competing_teams_travelers_pkey PRIMARY KEY (id);


--
-- Name: event_result_static_files event_result_static_files_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_result_static_files
    ADD CONSTRAINT event_result_static_files_pkey PRIMARY KEY (id);


--
-- Name: event_results event_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_results
    ADD CONSTRAINT event_results_pkey PRIMARY KEY (id);


--
-- Name: flight_airports flight_airports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_airports
    ADD CONSTRAINT flight_airports_pkey PRIMARY KEY (id);


--
-- Name: flight_legs flight_legs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_legs
    ADD CONSTRAINT flight_legs_pkey PRIMARY KEY (id);


--
-- Name: flight_schedules flight_schedules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_schedules
    ADD CONSTRAINT flight_schedules_pkey PRIMARY KEY (id);


--
-- Name: flight_tickets flight_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_tickets
    ADD CONSTRAINT flight_tickets_pkey PRIMARY KEY (id);


--
-- Name: fundraising_idea_images fundraising_idea_images_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fundraising_idea_images
    ADD CONSTRAINT fundraising_idea_images_pkey PRIMARY KEY (id);


--
-- Name: fundraising_ideas fundraising_ideas_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fundraising_ideas
    ADD CONSTRAINT fundraising_ideas_pkey PRIMARY KEY (id);


--
-- Name: import_athletes import_athletes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_athletes
    ADD CONSTRAINT import_athletes_pkey PRIMARY KEY (id);


--
-- Name: import_backups import_backups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_backups
    ADD CONSTRAINT import_backups_pkey PRIMARY KEY (id);


--
-- Name: import_errors import_errors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_errors
    ADD CONSTRAINT import_errors_pkey PRIMARY KEY (id);


--
-- Name: import_matches import_matches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_matches
    ADD CONSTRAINT import_matches_pkey PRIMARY KEY (id);


--
-- Name: interests interests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interests
    ADD CONSTRAINT interests_pkey PRIMARY KEY (id);


--
-- Name: invite_rules invite_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_rules
    ADD CONSTRAINT invite_rules_pkey PRIMARY KEY (id);


--
-- Name: invite_stats invite_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_stats
    ADD CONSTRAINT invite_stats_pkey PRIMARY KEY (id);


--
-- Name: mailings mailings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mailings
    ADD CONSTRAINT mailings_pkey PRIMARY KEY (id);


--
-- Name: meeting_registrations meeting_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_registrations
    ADD CONSTRAINT meeting_registrations_pkey PRIMARY KEY (id);


--
-- Name: meeting_video_views meeting_video_views_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_video_views
    ADD CONSTRAINT meeting_video_views_pkey PRIMARY KEY (id);


--
-- Name: meeting_videos meeting_videos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meeting_videos
    ADD CONSTRAINT meeting_videos_pkey PRIMARY KEY (id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: officials officials_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.officials
    ADD CONSTRAINT officials_pkey PRIMARY KEY (id);


--
-- Name: participants participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT participants_pkey PRIMARY KEY (id);


--
-- Name: payment_items payment_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_items
    ADD CONSTRAINT payment_items_pkey PRIMARY KEY (id);


--
-- Name: payment_join_terms payment_join_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_join_terms
    ADD CONSTRAINT payment_join_terms_pkey PRIMARY KEY (id);


--
-- Name: payment_remittances payment_remittances_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_remittances
    ADD CONSTRAINT payment_remittances_pkey PRIMARY KEY (id);


--
-- Name: payment_terms payment_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_terms
    ADD CONSTRAINT payment_terms_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: privacy_policies privacy_policies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policies
    ADD CONSTRAINT privacy_policies_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: schools schools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (id);


--
-- Name: sent_mails sent_mails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sent_mails
    ADD CONSTRAINT sent_mails_pkey PRIMARY KEY (id);


--
-- Name: shirt_order_items shirt_order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_items
    ADD CONSTRAINT shirt_order_items_pkey PRIMARY KEY (id);


--
-- Name: shirt_order_shipments shirt_order_shipments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_shipments
    ADD CONSTRAINT shirt_order_shipments_pkey PRIMARY KEY (id);


--
-- Name: shirt_orders shirt_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_orders
    ADD CONSTRAINT shirt_orders_pkey PRIMARY KEY (id);


--
-- Name: sources sources_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sources
    ADD CONSTRAINT sources_pkey PRIMARY KEY (id);


--
-- Name: sport_events sport_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_events
    ADD CONSTRAINT sport_events_pkey PRIMARY KEY (id);


--
-- Name: sport_infos sport_infos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_infos
    ADD CONSTRAINT sport_infos_pkey PRIMARY KEY (id);


--
-- Name: sports sports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sports
    ADD CONSTRAINT sports_pkey PRIMARY KEY (id);


--
-- Name: staff_assignment_visits staff_assignment_visits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_assignment_visits
    ADD CONSTRAINT staff_assignment_visits_pkey PRIMARY KEY (id);


--
-- Name: staff_assignments staff_assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_assignments
    ADD CONSTRAINT staff_assignments_pkey PRIMARY KEY (id);


--
-- Name: staff_clocks staff_clocks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_clocks
    ADD CONSTRAINT staff_clocks_pkey PRIMARY KEY (id);


--
-- Name: staffs staffs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staffs
    ADD CONSTRAINT staffs_pkey PRIMARY KEY (id);


--
-- Name: states states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.states
    ADD CONSTRAINT states_pkey PRIMARY KEY (id);


--
-- Name: student_lists student_lists_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.student_lists
    ADD CONSTRAINT student_lists_pkey PRIMARY KEY (id);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: thank_you_ticket_terms thank_you_ticket_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thank_you_ticket_terms
    ADD CONSTRAINT thank_you_ticket_terms_pkey PRIMARY KEY (id);


--
-- Name: traveler_base_debits traveler_base_debits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_base_debits
    ADD CONSTRAINT traveler_base_debits_pkey PRIMARY KEY (id);


--
-- Name: traveler_buses traveler_buses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_buses
    ADD CONSTRAINT traveler_buses_pkey PRIMARY KEY (id);


--
-- Name: traveler_credits traveler_credits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_credits
    ADD CONSTRAINT traveler_credits_pkey PRIMARY KEY (id);


--
-- Name: traveler_debits traveler_debits_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_debits
    ADD CONSTRAINT traveler_debits_pkey PRIMARY KEY (id);


--
-- Name: traveler_hotels traveler_hotels_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_hotels
    ADD CONSTRAINT traveler_hotels_pkey PRIMARY KEY (id);


--
-- Name: traveler_offers traveler_offers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_offers
    ADD CONSTRAINT traveler_offers_pkey PRIMARY KEY (id);


--
-- Name: traveler_requests traveler_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_requests
    ADD CONSTRAINT traveler_requests_pkey PRIMARY KEY (id);


--
-- Name: traveler_rooms traveler_rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_rooms
    ADD CONSTRAINT traveler_rooms_pkey PRIMARY KEY (id);


--
-- Name: travelers travelers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.travelers
    ADD CONSTRAINT travelers_pkey PRIMARY KEY (id);


--
-- Name: unsubscribers unsubscribers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.unsubscribers
    ADD CONSTRAINT unsubscribers_pkey PRIMARY KEY (id);


--
-- Name: user_ambassadors user_ambassadors_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ambassadors
    ADD CONSTRAINT user_ambassadors_pkey PRIMARY KEY (id);


--
-- Name: user_event_registrations user_event_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_event_registrations
    ADD CONSTRAINT user_event_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_interest_histories user_interest_histories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interest_histories
    ADD CONSTRAINT user_interest_histories_pkey PRIMARY KEY (id);


--
-- Name: user_marathon_registrations user_marathon_registrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_marathon_registrations
    ADD CONSTRAINT user_marathon_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_messages user_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_messages
    ADD CONSTRAINT user_messages_pkey PRIMARY KEY (id);


--
-- Name: user_nationalities user_nationalities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_nationalities
    ADD CONSTRAINT user_nationalities_pkey PRIMARY KEY (id);


--
-- Name: user_overrides user_overrides_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_overrides
    ADD CONSTRAINT user_overrides_pkey PRIMARY KEY (id);


--
-- Name: user_passport_authorities user_passport_authorities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passport_authorities
    ADD CONSTRAINT user_passport_authorities_pkey PRIMARY KEY (id);


--
-- Name: user_passports user_passports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passports
    ADD CONSTRAINT user_passports_pkey PRIMARY KEY (id);


--
-- Name: user_refund_requests user_refund_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_refund_requests
    ADD CONSTRAINT user_refund_requests_pkey PRIMARY KEY (id);


--
-- Name: user_relations user_relations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relations
    ADD CONSTRAINT user_relations_pkey PRIMARY KEY (id);


--
-- Name: user_relationship_types user_relationship_type_inverse_uniqueness; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relationship_types
    ADD CONSTRAINT user_relationship_type_inverse_uniqueness UNIQUE (inverse);


--
-- Name: user_relationship_types user_relationship_type_value_pk; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relationship_types
    ADD CONSTRAINT user_relationship_type_value_pk PRIMARY KEY (value);


--
-- Name: user_transfer_expectations user_transfer_expectations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_transfer_expectations
    ADD CONSTRAINT user_transfer_expectations_pkey PRIMARY KEY (id);


--
-- Name: user_travel_preparations user_travel_preparations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_travel_preparations
    ADD CONSTRAINT user_travel_preparations_pkey PRIMARY KEY (id);


--
-- Name: user_uniform_orders user_uniform_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_uniform_orders
    ADD CONSTRAINT user_uniform_orders_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: view_trackers view_trackers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_trackers
    ADD CONSTRAINT view_trackers_pkey PRIMARY KEY (id);


--
-- Name: competing_teams year_2019_competing_teams_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams
    ADD CONSTRAINT year_2019_competing_teams_pkey PRIMARY KEY (id);


--
-- Name: competing_teams_travelers year_2019_competing_teams_travelers_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams_travelers
    ADD CONSTRAINT year_2019_competing_teams_travelers_pkey PRIMARY KEY (id);


--
-- Name: flight_legs year_2019_flight_legs_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs
    ADD CONSTRAINT year_2019_flight_legs_pkey PRIMARY KEY (id);


--
-- Name: flight_schedules year_2019_flight_schedules_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules
    ADD CONSTRAINT year_2019_flight_schedules_pkey PRIMARY KEY (id);


--
-- Name: flight_tickets year_2019_flight_tickets_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets
    ADD CONSTRAINT year_2019_flight_tickets_pkey PRIMARY KEY (id);


--
-- Name: mailings year_2019_mailings_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings
    ADD CONSTRAINT year_2019_mailings_pkey PRIMARY KEY (id);


--
-- Name: meeting_registrations year_2019_meeting_registrations_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations
    ADD CONSTRAINT year_2019_meeting_registrations_pkey PRIMARY KEY (id);


--
-- Name: meeting_video_views year_2019_meeting_video_views_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views
    ADD CONSTRAINT year_2019_meeting_video_views_pkey PRIMARY KEY (id);


--
-- Name: payment_items year_2019_payment_items_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items
    ADD CONSTRAINT year_2019_payment_items_pkey PRIMARY KEY (id);


--
-- Name: payment_join_terms year_2019_payment_join_terms_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms
    ADD CONSTRAINT year_2019_payment_join_terms_pkey PRIMARY KEY (id);


--
-- Name: payment_remittances year_2019_payment_remittances_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_remittances
    ADD CONSTRAINT year_2019_payment_remittances_pkey PRIMARY KEY (id);


--
-- Name: payments year_2019_payments_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments
    ADD CONSTRAINT year_2019_payments_pkey PRIMARY KEY (id);


--
-- Name: sent_mails year_2019_sent_mails_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.sent_mails
    ADD CONSTRAINT year_2019_sent_mails_pkey PRIMARY KEY (id);


--
-- Name: staff_assignment_visits year_2019_staff_assignment_visits_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignment_visits
    ADD CONSTRAINT year_2019_staff_assignment_visits_pkey PRIMARY KEY (id);


--
-- Name: staff_assignments year_2019_staff_assignments_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments
    ADD CONSTRAINT year_2019_staff_assignments_pkey PRIMARY KEY (id);


--
-- Name: student_lists year_2019_student_lists_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.student_lists
    ADD CONSTRAINT year_2019_student_lists_pkey PRIMARY KEY (id);


--
-- Name: teams year_2019_teams_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams
    ADD CONSTRAINT year_2019_teams_pkey PRIMARY KEY (id);


--
-- Name: traveler_buses year_2019_traveler_buses_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses
    ADD CONSTRAINT year_2019_traveler_buses_pkey PRIMARY KEY (id);


--
-- Name: traveler_credits year_2019_traveler_credits_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits
    ADD CONSTRAINT year_2019_traveler_credits_pkey PRIMARY KEY (id);


--
-- Name: traveler_debits year_2019_traveler_debits_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits
    ADD CONSTRAINT year_2019_traveler_debits_pkey PRIMARY KEY (id);


--
-- Name: traveler_offers year_2019_traveler_offers_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers
    ADD CONSTRAINT year_2019_traveler_offers_pkey PRIMARY KEY (id);


--
-- Name: traveler_requests year_2019_traveler_requests_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_requests
    ADD CONSTRAINT year_2019_traveler_requests_pkey PRIMARY KEY (id);


--
-- Name: traveler_rooms year_2019_traveler_rooms_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms
    ADD CONSTRAINT year_2019_traveler_rooms_pkey PRIMARY KEY (id);


--
-- Name: travelers year_2019_travelers_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers
    ADD CONSTRAINT year_2019_travelers_pkey PRIMARY KEY (id);


--
-- Name: user_event_registrations year_2019_user_event_registrations_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations
    ADD CONSTRAINT year_2019_user_event_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_marathon_registrations year_2019_user_marathon_registrations_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations
    ADD CONSTRAINT year_2019_user_marathon_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_messages year_2019_user_messages_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages
    ADD CONSTRAINT year_2019_user_messages_pkey PRIMARY KEY (id);


--
-- Name: user_overrides year_2019_user_overrides_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_overrides
    ADD CONSTRAINT year_2019_user_overrides_pkey PRIMARY KEY (id);


--
-- Name: user_transfer_expectations year_2019_user_transfer_expectations_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations
    ADD CONSTRAINT year_2019_user_transfer_expectations_pkey PRIMARY KEY (id);


--
-- Name: user_travel_preparations year_2019_user_travel_preparations_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations
    ADD CONSTRAINT year_2019_user_travel_preparations_pkey PRIMARY KEY (id);


--
-- Name: user_uniform_orders year_2019_user_uniform_orders_pkey; Type: CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders
    ADD CONSTRAINT year_2019_user_uniform_orders_pkey PRIMARY KEY (id);


--
-- Name: competing_teams year_2020_competing_teams_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams
    ADD CONSTRAINT year_2020_competing_teams_pkey PRIMARY KEY (id);


--
-- Name: competing_teams_travelers year_2020_competing_teams_travelers_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams_travelers
    ADD CONSTRAINT year_2020_competing_teams_travelers_pkey PRIMARY KEY (id);


--
-- Name: flight_legs year_2020_flight_legs_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs
    ADD CONSTRAINT year_2020_flight_legs_pkey PRIMARY KEY (id);


--
-- Name: flight_schedules year_2020_flight_schedules_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules
    ADD CONSTRAINT year_2020_flight_schedules_pkey PRIMARY KEY (id);


--
-- Name: flight_tickets year_2020_flight_tickets_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets
    ADD CONSTRAINT year_2020_flight_tickets_pkey PRIMARY KEY (id);


--
-- Name: mailings year_2020_mailings_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings
    ADD CONSTRAINT year_2020_mailings_pkey PRIMARY KEY (id);


--
-- Name: meeting_registrations year_2020_meeting_registrations_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations
    ADD CONSTRAINT year_2020_meeting_registrations_pkey PRIMARY KEY (id);


--
-- Name: meeting_video_views year_2020_meeting_video_views_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views
    ADD CONSTRAINT year_2020_meeting_video_views_pkey PRIMARY KEY (id);


--
-- Name: payment_items year_2020_payment_items_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items
    ADD CONSTRAINT year_2020_payment_items_pkey PRIMARY KEY (id);


--
-- Name: payment_join_terms year_2020_payment_join_terms_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms
    ADD CONSTRAINT year_2020_payment_join_terms_pkey PRIMARY KEY (id);


--
-- Name: payment_remittances year_2020_payment_remittances_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_remittances
    ADD CONSTRAINT year_2020_payment_remittances_pkey PRIMARY KEY (id);


--
-- Name: payments year_2020_payments_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments
    ADD CONSTRAINT year_2020_payments_pkey PRIMARY KEY (id);


--
-- Name: sent_mails year_2020_sent_mails_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.sent_mails
    ADD CONSTRAINT year_2020_sent_mails_pkey PRIMARY KEY (id);


--
-- Name: staff_assignment_visits year_2020_staff_assignment_visits_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignment_visits
    ADD CONSTRAINT year_2020_staff_assignment_visits_pkey PRIMARY KEY (id);


--
-- Name: staff_assignments year_2020_staff_assignments_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments
    ADD CONSTRAINT year_2020_staff_assignments_pkey PRIMARY KEY (id);


--
-- Name: student_lists year_2020_student_lists_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.student_lists
    ADD CONSTRAINT year_2020_student_lists_pkey PRIMARY KEY (id);


--
-- Name: teams year_2020_teams_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams
    ADD CONSTRAINT year_2020_teams_pkey PRIMARY KEY (id);


--
-- Name: traveler_buses year_2020_traveler_buses_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses
    ADD CONSTRAINT year_2020_traveler_buses_pkey PRIMARY KEY (id);


--
-- Name: traveler_credits year_2020_traveler_credits_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits
    ADD CONSTRAINT year_2020_traveler_credits_pkey PRIMARY KEY (id);


--
-- Name: traveler_debits year_2020_traveler_debits_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits
    ADD CONSTRAINT year_2020_traveler_debits_pkey PRIMARY KEY (id);


--
-- Name: traveler_offers year_2020_traveler_offers_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers
    ADD CONSTRAINT year_2020_traveler_offers_pkey PRIMARY KEY (id);


--
-- Name: traveler_requests year_2020_traveler_requests_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_requests
    ADD CONSTRAINT year_2020_traveler_requests_pkey PRIMARY KEY (id);


--
-- Name: traveler_rooms year_2020_traveler_rooms_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms
    ADD CONSTRAINT year_2020_traveler_rooms_pkey PRIMARY KEY (id);


--
-- Name: travelers year_2020_travelers_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers
    ADD CONSTRAINT year_2020_travelers_pkey PRIMARY KEY (id);


--
-- Name: user_event_registrations year_2020_user_event_registrations_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations
    ADD CONSTRAINT year_2020_user_event_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_marathon_registrations year_2020_user_marathon_registrations_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations
    ADD CONSTRAINT year_2020_user_marathon_registrations_pkey PRIMARY KEY (id);


--
-- Name: user_messages year_2020_user_messages_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages
    ADD CONSTRAINT year_2020_user_messages_pkey PRIMARY KEY (id);


--
-- Name: user_overrides year_2020_user_overrides_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_overrides
    ADD CONSTRAINT year_2020_user_overrides_pkey PRIMARY KEY (id);


--
-- Name: user_transfer_expectations year_2020_user_transfer_expectations_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations
    ADD CONSTRAINT year_2020_user_transfer_expectations_pkey PRIMARY KEY (id);


--
-- Name: user_travel_preparations year_2020_user_travel_preparations_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations
    ADD CONSTRAINT year_2020_user_travel_preparations_pkey PRIMARY KEY (id);


--
-- Name: user_uniform_orders year_2020_user_uniform_orders_pkey; Type: CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders
    ADD CONSTRAINT year_2020_user_uniform_orders_pkey PRIMARY KEY (id);


--
-- Name: logged_actions_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_action_idx ON auditing.logged_actions USING btree (action);


--
-- Name: logged_actions_action_tstamp_tx_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_action_tstamp_tx_stm_idx ON auditing.logged_actions USING btree (action_tstamp_stm);


--
-- Name: logged_actions_active_storage_attachments_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_action_idx ON auditing.logged_actions_active_storage_attachments USING btree (action);


--
-- Name: logged_actions_active_storage_attachments_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_action_tstamp_stm_idx ON auditing.logged_actions_active_storage_attachments USING btree (action_tstamp_stm);


--
-- Name: logged_actions_active_storage_attachments_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_full_name_idx ON auditing.logged_actions_active_storage_attachments USING btree (full_name);


--
-- Name: logged_actions_active_storage_attachments_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_relid_idx ON auditing.logged_actions_active_storage_attachments USING btree (relid);


--
-- Name: logged_actions_active_storage_attachments_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_row_id_idx ON auditing.logged_actions_active_storage_attachments USING btree (row_id);


--
-- Name: logged_actions_active_storage_attachments_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_attachments_table_name_idx ON auditing.logged_actions_active_storage_attachments USING btree (table_name);


--
-- Name: logged_actions_active_storage_blobs_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_action_idx ON auditing.logged_actions_active_storage_blobs USING btree (action);


--
-- Name: logged_actions_active_storage_blobs_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_action_tstamp_stm_idx ON auditing.logged_actions_active_storage_blobs USING btree (action_tstamp_stm);


--
-- Name: logged_actions_active_storage_blobs_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_full_name_idx ON auditing.logged_actions_active_storage_blobs USING btree (full_name);


--
-- Name: logged_actions_active_storage_blobs_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_relid_idx ON auditing.logged_actions_active_storage_blobs USING btree (relid);


--
-- Name: logged_actions_active_storage_blobs_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_row_id_idx ON auditing.logged_actions_active_storage_blobs USING btree (row_id);


--
-- Name: logged_actions_active_storage_blobs_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_active_storage_blobs_table_name_idx ON auditing.logged_actions_active_storage_blobs USING btree (table_name);


--
-- Name: logged_actions_addresses_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_action_idx ON auditing.logged_actions_addresses USING btree (action);


--
-- Name: logged_actions_addresses_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_action_tstamp_stm_idx ON auditing.logged_actions_addresses USING btree (action_tstamp_stm);


--
-- Name: logged_actions_addresses_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_full_name_idx ON auditing.logged_actions_addresses USING btree (full_name);


--
-- Name: logged_actions_addresses_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_relid_idx ON auditing.logged_actions_addresses USING btree (relid);


--
-- Name: logged_actions_addresses_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_row_id_idx ON auditing.logged_actions_addresses USING btree (row_id);


--
-- Name: logged_actions_addresses_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_addresses_table_name_idx ON auditing.logged_actions_addresses USING btree (table_name);


--
-- Name: logged_actions_athletes_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_action_idx ON auditing.logged_actions_athletes USING btree (action);


--
-- Name: logged_actions_athletes_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_action_tstamp_stm_idx ON auditing.logged_actions_athletes USING btree (action_tstamp_stm);


--
-- Name: logged_actions_athletes_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_full_name_idx ON auditing.logged_actions_athletes USING btree (full_name);


--
-- Name: logged_actions_athletes_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_relid_idx ON auditing.logged_actions_athletes USING btree (relid);


--
-- Name: logged_actions_athletes_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_row_id_idx ON auditing.logged_actions_athletes USING btree (row_id);


--
-- Name: logged_actions_athletes_sports_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_action_idx ON auditing.logged_actions_athletes_sports USING btree (action);


--
-- Name: logged_actions_athletes_sports_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_action_tstamp_stm_idx ON auditing.logged_actions_athletes_sports USING btree (action_tstamp_stm);


--
-- Name: logged_actions_athletes_sports_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_full_name_idx ON auditing.logged_actions_athletes_sports USING btree (full_name);


--
-- Name: logged_actions_athletes_sports_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_relid_idx ON auditing.logged_actions_athletes_sports USING btree (relid);


--
-- Name: logged_actions_athletes_sports_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_row_id_idx ON auditing.logged_actions_athletes_sports USING btree (row_id);


--
-- Name: logged_actions_athletes_sports_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_sports_table_name_idx ON auditing.logged_actions_athletes_sports USING btree (table_name);


--
-- Name: logged_actions_athletes_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_athletes_table_name_idx ON auditing.logged_actions_athletes USING btree (table_name);


--
-- Name: logged_actions_coaches_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_action_idx ON auditing.logged_actions_coaches USING btree (action);


--
-- Name: logged_actions_coaches_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_action_tstamp_stm_idx ON auditing.logged_actions_coaches USING btree (action_tstamp_stm);


--
-- Name: logged_actions_coaches_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_full_name_idx ON auditing.logged_actions_coaches USING btree (full_name);


--
-- Name: logged_actions_coaches_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_relid_idx ON auditing.logged_actions_coaches USING btree (relid);


--
-- Name: logged_actions_coaches_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_row_id_idx ON auditing.logged_actions_coaches USING btree (row_id);


--
-- Name: logged_actions_coaches_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_coaches_table_name_idx ON auditing.logged_actions_coaches USING btree (table_name);


--
-- Name: logged_actions_competing_teams_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_action_idx ON auditing.logged_actions_competing_teams USING btree (action);


--
-- Name: logged_actions_competing_teams_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_action_tstamp_stm_idx ON auditing.logged_actions_competing_teams USING btree (action_tstamp_stm);


--
-- Name: logged_actions_competing_teams_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_full_name_idx ON auditing.logged_actions_competing_teams USING btree (full_name);


--
-- Name: logged_actions_competing_teams_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_relid_idx ON auditing.logged_actions_competing_teams USING btree (relid);


--
-- Name: logged_actions_competing_teams_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_row_id_idx ON auditing.logged_actions_competing_teams USING btree (row_id);


--
-- Name: logged_actions_competing_teams_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_table_name_idx ON auditing.logged_actions_competing_teams USING btree (table_name);


--
-- Name: logged_actions_competing_teams_travelers_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_action_idx ON auditing.logged_actions_competing_teams_travelers USING btree (action);


--
-- Name: logged_actions_competing_teams_travelers_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_action_tstamp_stm_idx ON auditing.logged_actions_competing_teams_travelers USING btree (action_tstamp_stm);


--
-- Name: logged_actions_competing_teams_travelers_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_full_name_idx ON auditing.logged_actions_competing_teams_travelers USING btree (full_name);


--
-- Name: logged_actions_competing_teams_travelers_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_relid_idx ON auditing.logged_actions_competing_teams_travelers USING btree (relid);


--
-- Name: logged_actions_competing_teams_travelers_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_row_id_idx ON auditing.logged_actions_competing_teams_travelers USING btree (row_id);


--
-- Name: logged_actions_competing_teams_travelers_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_competing_teams_travelers_table_name_idx ON auditing.logged_actions_competing_teams_travelers USING btree (table_name);


--
-- Name: logged_actions_event_result_static_files_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_action_idx ON auditing.logged_actions_event_result_static_files USING btree (action);


--
-- Name: logged_actions_event_result_static_files_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_action_tstamp_stm_idx ON auditing.logged_actions_event_result_static_files USING btree (action_tstamp_stm);


--
-- Name: logged_actions_event_result_static_files_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_full_name_idx ON auditing.logged_actions_event_result_static_files USING btree (full_name);


--
-- Name: logged_actions_event_result_static_files_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_relid_idx ON auditing.logged_actions_event_result_static_files USING btree (relid);


--
-- Name: logged_actions_event_result_static_files_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_row_id_idx ON auditing.logged_actions_event_result_static_files USING btree (row_id);


--
-- Name: logged_actions_event_result_static_files_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_result_static_files_table_name_idx ON auditing.logged_actions_event_result_static_files USING btree (table_name);


--
-- Name: logged_actions_event_results_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_action_idx ON auditing.logged_actions_event_results USING btree (action);


--
-- Name: logged_actions_event_results_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_action_tstamp_stm_idx ON auditing.logged_actions_event_results USING btree (action_tstamp_stm);


--
-- Name: logged_actions_event_results_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_full_name_idx ON auditing.logged_actions_event_results USING btree (full_name);


--
-- Name: logged_actions_event_results_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_relid_idx ON auditing.logged_actions_event_results USING btree (relid);


--
-- Name: logged_actions_event_results_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_row_id_idx ON auditing.logged_actions_event_results USING btree (row_id);


--
-- Name: logged_actions_event_results_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_event_results_table_name_idx ON auditing.logged_actions_event_results USING btree (table_name);


--
-- Name: logged_actions_flight_airports_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_action_idx ON auditing.logged_actions_flight_airports USING btree (action);


--
-- Name: logged_actions_flight_airports_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_action_tstamp_stm_idx ON auditing.logged_actions_flight_airports USING btree (action_tstamp_stm);


--
-- Name: logged_actions_flight_airports_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_full_name_idx ON auditing.logged_actions_flight_airports USING btree (full_name);


--
-- Name: logged_actions_flight_airports_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_relid_idx ON auditing.logged_actions_flight_airports USING btree (relid);


--
-- Name: logged_actions_flight_airports_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_row_id_idx ON auditing.logged_actions_flight_airports USING btree (row_id);


--
-- Name: logged_actions_flight_airports_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_airports_table_name_idx ON auditing.logged_actions_flight_airports USING btree (table_name);


--
-- Name: logged_actions_flight_legs_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_action_idx ON auditing.logged_actions_flight_legs USING btree (action);


--
-- Name: logged_actions_flight_legs_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_action_tstamp_stm_idx ON auditing.logged_actions_flight_legs USING btree (action_tstamp_stm);


--
-- Name: logged_actions_flight_legs_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_full_name_idx ON auditing.logged_actions_flight_legs USING btree (full_name);


--
-- Name: logged_actions_flight_legs_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_relid_idx ON auditing.logged_actions_flight_legs USING btree (relid);


--
-- Name: logged_actions_flight_legs_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_row_id_idx ON auditing.logged_actions_flight_legs USING btree (row_id);


--
-- Name: logged_actions_flight_legs_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_legs_table_name_idx ON auditing.logged_actions_flight_legs USING btree (table_name);


--
-- Name: logged_actions_flight_schedules_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_action_idx ON auditing.logged_actions_flight_schedules USING btree (action);


--
-- Name: logged_actions_flight_schedules_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_action_tstamp_stm_idx ON auditing.logged_actions_flight_schedules USING btree (action_tstamp_stm);


--
-- Name: logged_actions_flight_schedules_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_full_name_idx ON auditing.logged_actions_flight_schedules USING btree (full_name);


--
-- Name: logged_actions_flight_schedules_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_relid_idx ON auditing.logged_actions_flight_schedules USING btree (relid);


--
-- Name: logged_actions_flight_schedules_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_row_id_idx ON auditing.logged_actions_flight_schedules USING btree (row_id);


--
-- Name: logged_actions_flight_schedules_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_schedules_table_name_idx ON auditing.logged_actions_flight_schedules USING btree (table_name);


--
-- Name: logged_actions_flight_tickets_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_action_idx ON auditing.logged_actions_flight_tickets USING btree (action);


--
-- Name: logged_actions_flight_tickets_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_action_tstamp_stm_idx ON auditing.logged_actions_flight_tickets USING btree (action_tstamp_stm);


--
-- Name: logged_actions_flight_tickets_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_full_name_idx ON auditing.logged_actions_flight_tickets USING btree (full_name);


--
-- Name: logged_actions_flight_tickets_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_relid_idx ON auditing.logged_actions_flight_tickets USING btree (relid);


--
-- Name: logged_actions_flight_tickets_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_row_id_idx ON auditing.logged_actions_flight_tickets USING btree (row_id);


--
-- Name: logged_actions_flight_tickets_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_flight_tickets_table_name_idx ON auditing.logged_actions_flight_tickets USING btree (table_name);


--
-- Name: logged_actions_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_full_name_idx ON auditing.logged_actions USING btree (full_name);


--
-- Name: logged_actions_mailings_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_action_idx ON auditing.logged_actions_mailings USING btree (action);


--
-- Name: logged_actions_mailings_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_action_tstamp_stm_idx ON auditing.logged_actions_mailings USING btree (action_tstamp_stm);


--
-- Name: logged_actions_mailings_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_full_name_idx ON auditing.logged_actions_mailings USING btree (full_name);


--
-- Name: logged_actions_mailings_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_relid_idx ON auditing.logged_actions_mailings USING btree (relid);


--
-- Name: logged_actions_mailings_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_row_id_idx ON auditing.logged_actions_mailings USING btree (row_id);


--
-- Name: logged_actions_mailings_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_mailings_table_name_idx ON auditing.logged_actions_mailings USING btree (table_name);


--
-- Name: logged_actions_meeting_registrations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_action_idx ON auditing.logged_actions_meeting_registrations USING btree (action);


--
-- Name: logged_actions_meeting_registrations_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_action_tstamp_stm_idx ON auditing.logged_actions_meeting_registrations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_meeting_registrations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_full_name_idx ON auditing.logged_actions_meeting_registrations USING btree (full_name);


--
-- Name: logged_actions_meeting_registrations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_relid_idx ON auditing.logged_actions_meeting_registrations USING btree (relid);


--
-- Name: logged_actions_meeting_registrations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_row_id_idx ON auditing.logged_actions_meeting_registrations USING btree (row_id);


--
-- Name: logged_actions_meeting_registrations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_registrations_table_name_idx ON auditing.logged_actions_meeting_registrations USING btree (table_name);


--
-- Name: logged_actions_meeting_video_views_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_action_idx ON auditing.logged_actions_meeting_video_views USING btree (action);


--
-- Name: logged_actions_meeting_video_views_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_action_tstamp_stm_idx ON auditing.logged_actions_meeting_video_views USING btree (action_tstamp_stm);


--
-- Name: logged_actions_meeting_video_views_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_full_name_idx ON auditing.logged_actions_meeting_video_views USING btree (full_name);


--
-- Name: logged_actions_meeting_video_views_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_relid_idx ON auditing.logged_actions_meeting_video_views USING btree (relid);


--
-- Name: logged_actions_meeting_video_views_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_row_id_idx ON auditing.logged_actions_meeting_video_views USING btree (row_id);


--
-- Name: logged_actions_meeting_video_views_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_video_views_table_name_idx ON auditing.logged_actions_meeting_video_views USING btree (table_name);


--
-- Name: logged_actions_meeting_videos_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_action_idx ON auditing.logged_actions_meeting_videos USING btree (action);


--
-- Name: logged_actions_meeting_videos_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_action_tstamp_stm_idx ON auditing.logged_actions_meeting_videos USING btree (action_tstamp_stm);


--
-- Name: logged_actions_meeting_videos_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_full_name_idx ON auditing.logged_actions_meeting_videos USING btree (full_name);


--
-- Name: logged_actions_meeting_videos_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_relid_idx ON auditing.logged_actions_meeting_videos USING btree (relid);


--
-- Name: logged_actions_meeting_videos_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_row_id_idx ON auditing.logged_actions_meeting_videos USING btree (row_id);


--
-- Name: logged_actions_meeting_videos_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meeting_videos_table_name_idx ON auditing.logged_actions_meeting_videos USING btree (table_name);


--
-- Name: logged_actions_meetings_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_action_idx ON auditing.logged_actions_meetings USING btree (action);


--
-- Name: logged_actions_meetings_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_action_tstamp_stm_idx ON auditing.logged_actions_meetings USING btree (action_tstamp_stm);


--
-- Name: logged_actions_meetings_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_full_name_idx ON auditing.logged_actions_meetings USING btree (full_name);


--
-- Name: logged_actions_meetings_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_relid_idx ON auditing.logged_actions_meetings USING btree (relid);


--
-- Name: logged_actions_meetings_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_row_id_idx ON auditing.logged_actions_meetings USING btree (row_id);


--
-- Name: logged_actions_meetings_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_meetings_table_name_idx ON auditing.logged_actions_meetings USING btree (table_name);


--
-- Name: logged_actions_officials_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_action_idx ON auditing.logged_actions_officials USING btree (action);


--
-- Name: logged_actions_officials_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_action_tstamp_stm_idx ON auditing.logged_actions_officials USING btree (action_tstamp_stm);


--
-- Name: logged_actions_officials_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_full_name_idx ON auditing.logged_actions_officials USING btree (full_name);


--
-- Name: logged_actions_officials_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_relid_idx ON auditing.logged_actions_officials USING btree (relid);


--
-- Name: logged_actions_officials_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_row_id_idx ON auditing.logged_actions_officials USING btree (row_id);


--
-- Name: logged_actions_officials_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_officials_table_name_idx ON auditing.logged_actions_officials USING btree (table_name);


--
-- Name: logged_actions_payment_items_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_action_idx ON auditing.logged_actions_payment_items USING btree (action);


--
-- Name: logged_actions_payment_items_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_action_tstamp_stm_idx ON auditing.logged_actions_payment_items USING btree (action_tstamp_stm);


--
-- Name: logged_actions_payment_items_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_full_name_idx ON auditing.logged_actions_payment_items USING btree (full_name);


--
-- Name: logged_actions_payment_items_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_relid_idx ON auditing.logged_actions_payment_items USING btree (relid);


--
-- Name: logged_actions_payment_items_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_row_id_idx ON auditing.logged_actions_payment_items USING btree (row_id);


--
-- Name: logged_actions_payment_items_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_items_table_name_idx ON auditing.logged_actions_payment_items USING btree (table_name);


--
-- Name: logged_actions_payment_remittances_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_action_idx ON auditing.logged_actions_payment_remittances USING btree (action);


--
-- Name: logged_actions_payment_remittances_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_action_tstamp_stm_idx ON auditing.logged_actions_payment_remittances USING btree (action_tstamp_stm);


--
-- Name: logged_actions_payment_remittances_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_full_name_idx ON auditing.logged_actions_payment_remittances USING btree (full_name);


--
-- Name: logged_actions_payment_remittances_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_relid_idx ON auditing.logged_actions_payment_remittances USING btree (relid);


--
-- Name: logged_actions_payment_remittances_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_row_id_idx ON auditing.logged_actions_payment_remittances USING btree (row_id);


--
-- Name: logged_actions_payment_remittances_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payment_remittances_table_name_idx ON auditing.logged_actions_payment_remittances USING btree (table_name);


--
-- Name: logged_actions_payments_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_action_idx ON auditing.logged_actions_payments USING btree (action);


--
-- Name: logged_actions_payments_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_action_tstamp_stm_idx ON auditing.logged_actions_payments USING btree (action_tstamp_stm);


--
-- Name: logged_actions_payments_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_full_name_idx ON auditing.logged_actions_payments USING btree (full_name);


--
-- Name: logged_actions_payments_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_relid_idx ON auditing.logged_actions_payments USING btree (relid);


--
-- Name: logged_actions_payments_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_row_id_idx ON auditing.logged_actions_payments USING btree (row_id);


--
-- Name: logged_actions_payments_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_payments_table_name_idx ON auditing.logged_actions_payments USING btree (table_name);


--
-- Name: logged_actions_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_relid_idx ON auditing.logged_actions USING btree (relid);


--
-- Name: logged_actions_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_row_id_idx ON auditing.logged_actions USING btree (row_id);


--
-- Name: logged_actions_schools_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_action_idx ON auditing.logged_actions_schools USING btree (action);


--
-- Name: logged_actions_schools_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_action_tstamp_stm_idx ON auditing.logged_actions_schools USING btree (action_tstamp_stm);


--
-- Name: logged_actions_schools_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_full_name_idx ON auditing.logged_actions_schools USING btree (full_name);


--
-- Name: logged_actions_schools_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_relid_idx ON auditing.logged_actions_schools USING btree (relid);


--
-- Name: logged_actions_schools_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_row_id_idx ON auditing.logged_actions_schools USING btree (row_id);


--
-- Name: logged_actions_schools_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_schools_table_name_idx ON auditing.logged_actions_schools USING btree (table_name);


--
-- Name: logged_actions_sent_mails_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_action_idx ON auditing.logged_actions_sent_mails USING btree (action);


--
-- Name: logged_actions_sent_mails_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_action_tstamp_stm_idx ON auditing.logged_actions_sent_mails USING btree (action_tstamp_stm);


--
-- Name: logged_actions_sent_mails_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_full_name_idx ON auditing.logged_actions_sent_mails USING btree (full_name);


--
-- Name: logged_actions_sent_mails_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_relid_idx ON auditing.logged_actions_sent_mails USING btree (relid);


--
-- Name: logged_actions_sent_mails_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_row_id_idx ON auditing.logged_actions_sent_mails USING btree (row_id);


--
-- Name: logged_actions_sent_mails_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sent_mails_table_name_idx ON auditing.logged_actions_sent_mails USING btree (table_name);


--
-- Name: logged_actions_shirt_order_items_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_action_idx ON auditing.logged_actions_shirt_order_items USING btree (action);


--
-- Name: logged_actions_shirt_order_items_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_action_tstamp_stm_idx ON auditing.logged_actions_shirt_order_items USING btree (action_tstamp_stm);


--
-- Name: logged_actions_shirt_order_items_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_full_name_idx ON auditing.logged_actions_shirt_order_items USING btree (full_name);


--
-- Name: logged_actions_shirt_order_items_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_relid_idx ON auditing.logged_actions_shirt_order_items USING btree (relid);


--
-- Name: logged_actions_shirt_order_items_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_row_id_idx ON auditing.logged_actions_shirt_order_items USING btree (row_id);


--
-- Name: logged_actions_shirt_order_items_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_items_table_name_idx ON auditing.logged_actions_shirt_order_items USING btree (table_name);


--
-- Name: logged_actions_shirt_order_shipments_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_action_idx ON auditing.logged_actions_shirt_order_shipments USING btree (action);


--
-- Name: logged_actions_shirt_order_shipments_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_action_tstamp_stm_idx ON auditing.logged_actions_shirt_order_shipments USING btree (action_tstamp_stm);


--
-- Name: logged_actions_shirt_order_shipments_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_full_name_idx ON auditing.logged_actions_shirt_order_shipments USING btree (full_name);


--
-- Name: logged_actions_shirt_order_shipments_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_relid_idx ON auditing.logged_actions_shirt_order_shipments USING btree (relid);


--
-- Name: logged_actions_shirt_order_shipments_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_row_id_idx ON auditing.logged_actions_shirt_order_shipments USING btree (row_id);


--
-- Name: logged_actions_shirt_order_shipments_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_order_shipments_table_name_idx ON auditing.logged_actions_shirt_order_shipments USING btree (table_name);


--
-- Name: logged_actions_shirt_orders_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_action_idx ON auditing.logged_actions_shirt_orders USING btree (action);


--
-- Name: logged_actions_shirt_orders_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_action_tstamp_stm_idx ON auditing.logged_actions_shirt_orders USING btree (action_tstamp_stm);


--
-- Name: logged_actions_shirt_orders_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_full_name_idx ON auditing.logged_actions_shirt_orders USING btree (full_name);


--
-- Name: logged_actions_shirt_orders_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_relid_idx ON auditing.logged_actions_shirt_orders USING btree (relid);


--
-- Name: logged_actions_shirt_orders_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_row_id_idx ON auditing.logged_actions_shirt_orders USING btree (row_id);


--
-- Name: logged_actions_shirt_orders_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_shirt_orders_table_name_idx ON auditing.logged_actions_shirt_orders USING btree (table_name);


--
-- Name: logged_actions_sources_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_action_idx ON auditing.logged_actions_sources USING btree (action);


--
-- Name: logged_actions_sources_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_action_tstamp_stm_idx ON auditing.logged_actions_sources USING btree (action_tstamp_stm);


--
-- Name: logged_actions_sources_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_full_name_idx ON auditing.logged_actions_sources USING btree (full_name);


--
-- Name: logged_actions_sources_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_relid_idx ON auditing.logged_actions_sources USING btree (relid);


--
-- Name: logged_actions_sources_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_row_id_idx ON auditing.logged_actions_sources USING btree (row_id);


--
-- Name: logged_actions_sources_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sources_table_name_idx ON auditing.logged_actions_sources USING btree (table_name);


--
-- Name: logged_actions_sports_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_action_idx ON auditing.logged_actions_sports USING btree (action);


--
-- Name: logged_actions_sports_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_action_tstamp_stm_idx ON auditing.logged_actions_sports USING btree (action_tstamp_stm);


--
-- Name: logged_actions_sports_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_full_name_idx ON auditing.logged_actions_sports USING btree (full_name);


--
-- Name: logged_actions_sports_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_relid_idx ON auditing.logged_actions_sports USING btree (relid);


--
-- Name: logged_actions_sports_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_row_id_idx ON auditing.logged_actions_sports USING btree (row_id);


--
-- Name: logged_actions_sports_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_sports_table_name_idx ON auditing.logged_actions_sports USING btree (table_name);


--
-- Name: logged_actions_staff_assignment_visits_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_action_idx ON auditing.logged_actions_staff_assignment_visits USING btree (action);


--
-- Name: logged_actions_staff_assignment_visits_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_action_tstamp_stm_idx ON auditing.logged_actions_staff_assignment_visits USING btree (action_tstamp_stm);


--
-- Name: logged_actions_staff_assignment_visits_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_full_name_idx ON auditing.logged_actions_staff_assignment_visits USING btree (full_name);


--
-- Name: logged_actions_staff_assignment_visits_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_relid_idx ON auditing.logged_actions_staff_assignment_visits USING btree (relid);


--
-- Name: logged_actions_staff_assignment_visits_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_row_id_idx ON auditing.logged_actions_staff_assignment_visits USING btree (row_id);


--
-- Name: logged_actions_staff_assignment_visits_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignment_visits_table_name_idx ON auditing.logged_actions_staff_assignment_visits USING btree (table_name);


--
-- Name: logged_actions_staff_assignments_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_action_idx ON auditing.logged_actions_staff_assignments USING btree (action);


--
-- Name: logged_actions_staff_assignments_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_action_tstamp_stm_idx ON auditing.logged_actions_staff_assignments USING btree (action_tstamp_stm);


--
-- Name: logged_actions_staff_assignments_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_full_name_idx ON auditing.logged_actions_staff_assignments USING btree (full_name);


--
-- Name: logged_actions_staff_assignments_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_relid_idx ON auditing.logged_actions_staff_assignments USING btree (relid);


--
-- Name: logged_actions_staff_assignments_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_row_id_idx ON auditing.logged_actions_staff_assignments USING btree (row_id);


--
-- Name: logged_actions_staff_assignments_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staff_assignments_table_name_idx ON auditing.logged_actions_staff_assignments USING btree (table_name);


--
-- Name: logged_actions_staffs_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_action_idx ON auditing.logged_actions_staffs USING btree (action);


--
-- Name: logged_actions_staffs_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_action_tstamp_stm_idx ON auditing.logged_actions_staffs USING btree (action_tstamp_stm);


--
-- Name: logged_actions_staffs_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_full_name_idx ON auditing.logged_actions_staffs USING btree (full_name);


--
-- Name: logged_actions_staffs_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_relid_idx ON auditing.logged_actions_staffs USING btree (relid);


--
-- Name: logged_actions_staffs_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_row_id_idx ON auditing.logged_actions_staffs USING btree (row_id);


--
-- Name: logged_actions_staffs_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_staffs_table_name_idx ON auditing.logged_actions_staffs USING btree (table_name);


--
-- Name: logged_actions_states_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_action_idx ON auditing.logged_actions_states USING btree (action);


--
-- Name: logged_actions_states_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_action_tstamp_stm_idx ON auditing.logged_actions_states USING btree (action_tstamp_stm);


--
-- Name: logged_actions_states_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_full_name_idx ON auditing.logged_actions_states USING btree (full_name);


--
-- Name: logged_actions_states_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_relid_idx ON auditing.logged_actions_states USING btree (relid);


--
-- Name: logged_actions_states_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_row_id_idx ON auditing.logged_actions_states USING btree (row_id);


--
-- Name: logged_actions_states_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_states_table_name_idx ON auditing.logged_actions_states USING btree (table_name);


--
-- Name: logged_actions_student_lists_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_action_idx ON auditing.logged_actions_student_lists USING btree (action);


--
-- Name: logged_actions_student_lists_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_action_tstamp_stm_idx ON auditing.logged_actions_student_lists USING btree (action_tstamp_stm);


--
-- Name: logged_actions_student_lists_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_full_name_idx ON auditing.logged_actions_student_lists USING btree (full_name);


--
-- Name: logged_actions_student_lists_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_relid_idx ON auditing.logged_actions_student_lists USING btree (relid);


--
-- Name: logged_actions_student_lists_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_row_id_idx ON auditing.logged_actions_student_lists USING btree (row_id);


--
-- Name: logged_actions_student_lists_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_student_lists_table_name_idx ON auditing.logged_actions_student_lists USING btree (table_name);


--
-- Name: logged_actions_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_table_name_idx ON auditing.logged_actions USING btree (table_name);


--
-- Name: logged_actions_teams_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_action_idx ON auditing.logged_actions_teams USING btree (action);


--
-- Name: logged_actions_teams_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_action_tstamp_stm_idx ON auditing.logged_actions_teams USING btree (action_tstamp_stm);


--
-- Name: logged_actions_teams_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_full_name_idx ON auditing.logged_actions_teams USING btree (full_name);


--
-- Name: logged_actions_teams_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_relid_idx ON auditing.logged_actions_teams USING btree (relid);


--
-- Name: logged_actions_teams_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_row_id_idx ON auditing.logged_actions_teams USING btree (row_id);


--
-- Name: logged_actions_teams_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_teams_table_name_idx ON auditing.logged_actions_teams USING btree (table_name);


--
-- Name: logged_actions_traveler_base_debits_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_action_idx ON auditing.logged_actions_traveler_base_debits USING btree (action);


--
-- Name: logged_actions_traveler_base_debits_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_action_tstamp_stm_idx ON auditing.logged_actions_traveler_base_debits USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_base_debits_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_full_name_idx ON auditing.logged_actions_traveler_base_debits USING btree (full_name);


--
-- Name: logged_actions_traveler_base_debits_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_relid_idx ON auditing.logged_actions_traveler_base_debits USING btree (relid);


--
-- Name: logged_actions_traveler_base_debits_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_row_id_idx ON auditing.logged_actions_traveler_base_debits USING btree (row_id);


--
-- Name: logged_actions_traveler_base_debits_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_base_debits_table_name_idx ON auditing.logged_actions_traveler_base_debits USING btree (table_name);


--
-- Name: logged_actions_traveler_buses_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_action_idx ON auditing.logged_actions_traveler_buses USING btree (action);


--
-- Name: logged_actions_traveler_buses_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_action_tstamp_stm_idx ON auditing.logged_actions_traveler_buses USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_buses_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_full_name_idx ON auditing.logged_actions_traveler_buses USING btree (full_name);


--
-- Name: logged_actions_traveler_buses_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_relid_idx ON auditing.logged_actions_traveler_buses USING btree (relid);


--
-- Name: logged_actions_traveler_buses_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_row_id_idx ON auditing.logged_actions_traveler_buses USING btree (row_id);


--
-- Name: logged_actions_traveler_buses_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_table_name_idx ON auditing.logged_actions_traveler_buses USING btree (table_name);


--
-- Name: logged_actions_traveler_buses_travelers_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_action_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (action);


--
-- Name: logged_actions_traveler_buses_travelers_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_action_tstamp_stm_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_buses_travelers_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_full_name_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (full_name);


--
-- Name: logged_actions_traveler_buses_travelers_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_relid_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (relid);


--
-- Name: logged_actions_traveler_buses_travelers_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_row_id_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (row_id);


--
-- Name: logged_actions_traveler_buses_travelers_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_buses_travelers_table_name_idx ON auditing.logged_actions_traveler_buses_travelers USING btree (table_name);


--
-- Name: logged_actions_traveler_credits_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_action_idx ON auditing.logged_actions_traveler_credits USING btree (action);


--
-- Name: logged_actions_traveler_credits_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_action_tstamp_stm_idx ON auditing.logged_actions_traveler_credits USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_credits_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_full_name_idx ON auditing.logged_actions_traveler_credits USING btree (full_name);


--
-- Name: logged_actions_traveler_credits_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_relid_idx ON auditing.logged_actions_traveler_credits USING btree (relid);


--
-- Name: logged_actions_traveler_credits_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_row_id_idx ON auditing.logged_actions_traveler_credits USING btree (row_id);


--
-- Name: logged_actions_traveler_credits_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_credits_table_name_idx ON auditing.logged_actions_traveler_credits USING btree (table_name);


--
-- Name: logged_actions_traveler_debits_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_action_idx ON auditing.logged_actions_traveler_debits USING btree (action);


--
-- Name: logged_actions_traveler_debits_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_action_tstamp_stm_idx ON auditing.logged_actions_traveler_debits USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_debits_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_full_name_idx ON auditing.logged_actions_traveler_debits USING btree (full_name);


--
-- Name: logged_actions_traveler_debits_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_relid_idx ON auditing.logged_actions_traveler_debits USING btree (relid);


--
-- Name: logged_actions_traveler_debits_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_row_id_idx ON auditing.logged_actions_traveler_debits USING btree (row_id);


--
-- Name: logged_actions_traveler_debits_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_debits_table_name_idx ON auditing.logged_actions_traveler_debits USING btree (table_name);


--
-- Name: logged_actions_traveler_hotels_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_action_idx ON auditing.logged_actions_traveler_hotels USING btree (action);


--
-- Name: logged_actions_traveler_hotels_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_action_tstamp_stm_idx ON auditing.logged_actions_traveler_hotels USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_hotels_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_full_name_idx ON auditing.logged_actions_traveler_hotels USING btree (full_name);


--
-- Name: logged_actions_traveler_hotels_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_relid_idx ON auditing.logged_actions_traveler_hotels USING btree (relid);


--
-- Name: logged_actions_traveler_hotels_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_row_id_idx ON auditing.logged_actions_traveler_hotels USING btree (row_id);


--
-- Name: logged_actions_traveler_hotels_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_hotels_table_name_idx ON auditing.logged_actions_traveler_hotels USING btree (table_name);


--
-- Name: logged_actions_traveler_offers_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_action_idx ON auditing.logged_actions_traveler_offers USING btree (action);


--
-- Name: logged_actions_traveler_offers_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_action_tstamp_stm_idx ON auditing.logged_actions_traveler_offers USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_offers_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_full_name_idx ON auditing.logged_actions_traveler_offers USING btree (full_name);


--
-- Name: logged_actions_traveler_offers_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_relid_idx ON auditing.logged_actions_traveler_offers USING btree (relid);


--
-- Name: logged_actions_traveler_offers_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_row_id_idx ON auditing.logged_actions_traveler_offers USING btree (row_id);


--
-- Name: logged_actions_traveler_offers_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_offers_table_name_idx ON auditing.logged_actions_traveler_offers USING btree (table_name);


--
-- Name: logged_actions_traveler_rooms_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_action_idx ON auditing.logged_actions_traveler_rooms USING btree (action);


--
-- Name: logged_actions_traveler_rooms_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_action_tstamp_stm_idx ON auditing.logged_actions_traveler_rooms USING btree (action_tstamp_stm);


--
-- Name: logged_actions_traveler_rooms_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_full_name_idx ON auditing.logged_actions_traveler_rooms USING btree (full_name);


--
-- Name: logged_actions_traveler_rooms_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_relid_idx ON auditing.logged_actions_traveler_rooms USING btree (relid);


--
-- Name: logged_actions_traveler_rooms_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_row_id_idx ON auditing.logged_actions_traveler_rooms USING btree (row_id);


--
-- Name: logged_actions_traveler_rooms_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_traveler_rooms_table_name_idx ON auditing.logged_actions_traveler_rooms USING btree (table_name);


--
-- Name: logged_actions_travelers_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_action_idx ON auditing.logged_actions_travelers USING btree (action);


--
-- Name: logged_actions_travelers_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_action_tstamp_stm_idx ON auditing.logged_actions_travelers USING btree (action_tstamp_stm);


--
-- Name: logged_actions_travelers_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_full_name_idx ON auditing.logged_actions_travelers USING btree (full_name);


--
-- Name: logged_actions_travelers_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_relid_idx ON auditing.logged_actions_travelers USING btree (relid);


--
-- Name: logged_actions_travelers_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_row_id_idx ON auditing.logged_actions_travelers USING btree (row_id);


--
-- Name: logged_actions_travelers_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_travelers_table_name_idx ON auditing.logged_actions_travelers USING btree (table_name);


--
-- Name: logged_actions_user_ambassadors_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_action_idx ON auditing.logged_actions_user_ambassadors USING btree (action);


--
-- Name: logged_actions_user_ambassadors_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_action_tstamp_stm_idx ON auditing.logged_actions_user_ambassadors USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_ambassadors_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_full_name_idx ON auditing.logged_actions_user_ambassadors USING btree (full_name);


--
-- Name: logged_actions_user_ambassadors_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_relid_idx ON auditing.logged_actions_user_ambassadors USING btree (relid);


--
-- Name: logged_actions_user_ambassadors_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_row_id_idx ON auditing.logged_actions_user_ambassadors USING btree (row_id);


--
-- Name: logged_actions_user_ambassadors_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_ambassadors_table_name_idx ON auditing.logged_actions_user_ambassadors USING btree (table_name);


--
-- Name: logged_actions_user_event_registrations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_action_idx ON auditing.logged_actions_user_event_registrations USING btree (action);


--
-- Name: logged_actions_user_event_registrations_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_action_tstamp_stm_idx ON auditing.logged_actions_user_event_registrations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_event_registrations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_full_name_idx ON auditing.logged_actions_user_event_registrations USING btree (full_name);


--
-- Name: logged_actions_user_event_registrations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_relid_idx ON auditing.logged_actions_user_event_registrations USING btree (relid);


--
-- Name: logged_actions_user_event_registrations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_row_id_idx ON auditing.logged_actions_user_event_registrations USING btree (row_id);


--
-- Name: logged_actions_user_event_registrations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_event_registrations_table_name_idx ON auditing.logged_actions_user_event_registrations USING btree (table_name);


--
-- Name: logged_actions_user_marathon_registration_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registration_action_tstamp_stm_idx ON auditing.logged_actions_user_marathon_registrations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_marathon_registrations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registrations_action_idx ON auditing.logged_actions_user_marathon_registrations USING btree (action);


--
-- Name: logged_actions_user_marathon_registrations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registrations_full_name_idx ON auditing.logged_actions_user_marathon_registrations USING btree (full_name);


--
-- Name: logged_actions_user_marathon_registrations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registrations_relid_idx ON auditing.logged_actions_user_marathon_registrations USING btree (relid);


--
-- Name: logged_actions_user_marathon_registrations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registrations_row_id_idx ON auditing.logged_actions_user_marathon_registrations USING btree (row_id);


--
-- Name: logged_actions_user_marathon_registrations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_marathon_registrations_table_name_idx ON auditing.logged_actions_user_marathon_registrations USING btree (table_name);


--
-- Name: logged_actions_user_messages_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_action_idx ON auditing.logged_actions_user_messages USING btree (action);


--
-- Name: logged_actions_user_messages_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_action_tstamp_stm_idx ON auditing.logged_actions_user_messages USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_messages_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_full_name_idx ON auditing.logged_actions_user_messages USING btree (full_name);


--
-- Name: logged_actions_user_messages_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_relid_idx ON auditing.logged_actions_user_messages USING btree (relid);


--
-- Name: logged_actions_user_messages_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_row_id_idx ON auditing.logged_actions_user_messages USING btree (row_id);


--
-- Name: logged_actions_user_messages_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_messages_table_name_idx ON auditing.logged_actions_user_messages USING btree (table_name);


--
-- Name: logged_actions_user_overrides_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_action_idx ON auditing.logged_actions_user_overrides USING btree (action);


--
-- Name: logged_actions_user_overrides_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_action_tstamp_stm_idx ON auditing.logged_actions_user_overrides USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_overrides_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_full_name_idx ON auditing.logged_actions_user_overrides USING btree (full_name);


--
-- Name: logged_actions_user_overrides_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_relid_idx ON auditing.logged_actions_user_overrides USING btree (relid);


--
-- Name: logged_actions_user_overrides_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_row_id_idx ON auditing.logged_actions_user_overrides USING btree (row_id);


--
-- Name: logged_actions_user_overrides_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_overrides_table_name_idx ON auditing.logged_actions_user_overrides USING btree (table_name);


--
-- Name: logged_actions_user_relations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_action_idx ON auditing.logged_actions_user_relations USING btree (action);


--
-- Name: logged_actions_user_relations_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_action_tstamp_stm_idx ON auditing.logged_actions_user_relations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_relations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_full_name_idx ON auditing.logged_actions_user_relations USING btree (full_name);


--
-- Name: logged_actions_user_relations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_relid_idx ON auditing.logged_actions_user_relations USING btree (relid);


--
-- Name: logged_actions_user_relations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_row_id_idx ON auditing.logged_actions_user_relations USING btree (row_id);


--
-- Name: logged_actions_user_relations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_relations_table_name_idx ON auditing.logged_actions_user_relations USING btree (table_name);


--
-- Name: logged_actions_user_transfer_expectations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_action_idx ON auditing.logged_actions_user_transfer_expectations USING btree (action);


--
-- Name: logged_actions_user_transfer_expectations_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_action_tstamp_stm_idx ON auditing.logged_actions_user_transfer_expectations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_transfer_expectations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_full_name_idx ON auditing.logged_actions_user_transfer_expectations USING btree (full_name);


--
-- Name: logged_actions_user_transfer_expectations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_relid_idx ON auditing.logged_actions_user_transfer_expectations USING btree (relid);


--
-- Name: logged_actions_user_transfer_expectations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_row_id_idx ON auditing.logged_actions_user_transfer_expectations USING btree (row_id);


--
-- Name: logged_actions_user_transfer_expectations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_transfer_expectations_table_name_idx ON auditing.logged_actions_user_transfer_expectations USING btree (table_name);


--
-- Name: logged_actions_user_travel_preparations_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_action_idx ON auditing.logged_actions_user_travel_preparations USING btree (action);


--
-- Name: logged_actions_user_travel_preparations_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_action_tstamp_stm_idx ON auditing.logged_actions_user_travel_preparations USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_travel_preparations_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_full_name_idx ON auditing.logged_actions_user_travel_preparations USING btree (full_name);


--
-- Name: logged_actions_user_travel_preparations_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_relid_idx ON auditing.logged_actions_user_travel_preparations USING btree (relid);


--
-- Name: logged_actions_user_travel_preparations_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_row_id_idx ON auditing.logged_actions_user_travel_preparations USING btree (row_id);


--
-- Name: logged_actions_user_travel_preparations_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_travel_preparations_table_name_idx ON auditing.logged_actions_user_travel_preparations USING btree (table_name);


--
-- Name: logged_actions_user_uniform_orders_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_action_idx ON auditing.logged_actions_user_uniform_orders USING btree (action);


--
-- Name: logged_actions_user_uniform_orders_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_action_tstamp_stm_idx ON auditing.logged_actions_user_uniform_orders USING btree (action_tstamp_stm);


--
-- Name: logged_actions_user_uniform_orders_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_full_name_idx ON auditing.logged_actions_user_uniform_orders USING btree (full_name);


--
-- Name: logged_actions_user_uniform_orders_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_relid_idx ON auditing.logged_actions_user_uniform_orders USING btree (relid);


--
-- Name: logged_actions_user_uniform_orders_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_row_id_idx ON auditing.logged_actions_user_uniform_orders USING btree (row_id);


--
-- Name: logged_actions_user_uniform_orders_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_user_uniform_orders_table_name_idx ON auditing.logged_actions_user_uniform_orders USING btree (table_name);


--
-- Name: logged_actions_users_action_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_action_idx ON auditing.logged_actions_users USING btree (action);


--
-- Name: logged_actions_users_action_tstamp_stm_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_action_tstamp_stm_idx ON auditing.logged_actions_users USING btree (action_tstamp_stm);


--
-- Name: logged_actions_users_full_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_full_name_idx ON auditing.logged_actions_users USING btree (full_name);


--
-- Name: logged_actions_users_relid_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_relid_idx ON auditing.logged_actions_users USING btree (relid);


--
-- Name: logged_actions_users_row_id_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_row_id_idx ON auditing.logged_actions_users USING btree (row_id);


--
-- Name: logged_actions_users_table_name_idx; Type: INDEX; Schema: auditing; Owner: -
--

CREATE INDEX logged_actions_users_table_name_idx ON auditing.logged_actions_users USING btree (table_name);


--
-- Name: address_variants_candidate_ids_count_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX address_variants_candidate_ids_count_idx ON public.address_variants USING btree (array_upper(candidate_ids, 1));


--
-- Name: athletes_sports_transferable_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX athletes_sports_transferable_idx ON public.athletes_sports USING btree (transferability);


--
-- Name: expected_difficulty_and_status_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX expected_difficulty_and_status_index ON public.user_transfer_expectations USING btree (difficulty, status);


--
-- Name: expected_status_and_difficulty_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX expected_status_and_difficulty_index ON public.user_transfer_expectations USING btree (status, difficulty);


--
-- Name: expected_transfer_and_compete_index; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX expected_transfer_and_compete_index ON public.user_transfer_expectations USING btree (can_transfer, can_compete);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_address_variants_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_variants_on_address_id ON public.address_variants USING btree (address_id);


--
-- Name: index_address_variants_on_candidate_ids; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_address_variants_on_candidate_ids ON public.address_variants USING gin (candidate_ids);


--
-- Name: index_address_variants_on_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_address_variants_on_value ON public.address_variants USING btree (value);


--
-- Name: index_addresses_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_state_id ON public.addresses USING btree (state_id);


--
-- Name: index_addresses_on_student_list_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_student_list_id ON public.addresses USING btree (student_list_id);


--
-- Name: index_addresses_on_tz_offset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_addresses_on_tz_offset ON public.addresses USING btree (tz_offset);


--
-- Name: index_athletes_on_competing_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_competing_team_id ON public.athletes USING btree (competing_team_id);


--
-- Name: index_athletes_on_referring_coach_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_referring_coach_id ON public.athletes USING btree (referring_coach_id);


--
-- Name: index_athletes_on_respond_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_respond_date ON public.athletes USING btree (respond_date);


--
-- Name: index_athletes_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_school_id ON public.athletes USING btree (school_id);


--
-- Name: index_athletes_on_source_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_source_id ON public.athletes USING btree (source_id);


--
-- Name: index_athletes_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_sport_id ON public.athletes USING btree (sport_id);


--
-- Name: index_athletes_on_student_list_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_on_student_list_date ON public.athletes USING btree (student_list_date);


--
-- Name: index_athletes_sports_on_athlete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_sports_on_athlete_id ON public.athletes_sports USING btree (athlete_id);


--
-- Name: index_athletes_sports_on_invited; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_sports_on_invited ON public.athletes_sports USING btree (invited);


--
-- Name: index_athletes_sports_on_invited_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_sports_on_invited_date ON public.athletes_sports USING btree (invited_date);


--
-- Name: index_athletes_sports_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_athletes_sports_on_sport_id ON public.athletes_sports USING btree (sport_id);


--
-- Name: index_attachment_validations_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_attachment_validations_uniqueness ON public.better_record_attachment_validations USING btree (attachment_id, name);


--
-- Name: index_better_record_attachment_validations_on_attachment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_better_record_attachment_validations_on_attachment_id ON public.better_record_attachment_validations USING btree (attachment_id);


--
-- Name: index_chat_room_messages_on_chat_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_room_messages_on_chat_room_id ON public.chat_room_messages USING btree (chat_room_id);


--
-- Name: index_chat_room_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_room_messages_on_user_id ON public.chat_room_messages USING btree (user_id);


--
-- Name: index_chat_rooms_on_is_closed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_chat_rooms_on_is_closed ON public.chat_rooms USING btree (is_closed);


--
-- Name: index_coaches_on_competing_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coaches_on_competing_team_id ON public.coaches USING btree (competing_team_id);


--
-- Name: index_coaches_on_head_coach_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coaches_on_head_coach_id ON public.coaches USING btree (head_coach_id);


--
-- Name: index_coaches_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coaches_on_school_id ON public.coaches USING btree (school_id);


--
-- Name: index_coaches_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_coaches_on_sport_id ON public.coaches USING btree (sport_id);


--
-- Name: index_competing_teams_on_letter_and_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_letter_and_sport_id ON public.competing_teams USING btree (letter, sport_id);


--
-- Name: index_competing_teams_on_name_and_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_name_and_sport_id ON public.competing_teams USING btree (name, sport_id);


--
-- Name: index_competing_teams_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competing_teams_on_sport_id ON public.competing_teams USING btree (sport_id);


--
-- Name: index_competing_teams_travelers_on_competing_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_competing_team_id ON public.competing_teams_travelers USING btree (competing_team_id);


--
-- Name: index_competing_teams_travelers_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_traveler_id ON public.competing_teams_travelers USING btree (traveler_id);


--
-- Name: index_event_result_static_files_on_event_result_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_result_static_files_on_event_result_id ON public.event_result_static_files USING btree (event_result_id);


--
-- Name: index_event_results_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_event_results_on_sport_id ON public.event_results USING btree (sport_id);


--
-- Name: index_flight_airports_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_address_id ON public.flight_airports USING btree (address_id);


--
-- Name: index_flight_airports_on_carrier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_carrier ON public.flight_airports USING btree (carrier);


--
-- Name: index_flight_airports_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flight_airports_on_code ON public.flight_airports USING btree (code);


--
-- Name: index_flight_airports_on_dst; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_dst ON public.flight_airports USING btree (dst);


--
-- Name: index_flight_airports_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_name ON public.flight_airports USING btree (name);


--
-- Name: index_flight_airports_on_preferred; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_preferred ON public.flight_airports USING btree (preferred);


--
-- Name: index_flight_airports_on_selectable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_airports_on_selectable ON public.flight_airports USING btree (selectable);


--
-- Name: index_flight_legs_on_arriving_airport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_legs_on_arriving_airport_id ON public.flight_legs USING btree (arriving_airport_id);


--
-- Name: index_flight_legs_on_departing_airport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_legs_on_departing_airport_id ON public.flight_legs USING btree (departing_airport_id);


--
-- Name: index_flight_legs_on_schedule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_legs_on_schedule_id ON public.flight_legs USING btree (schedule_id);


--
-- Name: index_flight_schedules_on_parent_schedule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_schedules_on_parent_schedule_id ON public.flight_schedules USING btree (parent_schedule_id);


--
-- Name: index_flight_schedules_on_pnr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_flight_schedules_on_pnr ON public.flight_schedules USING btree (pnr);


--
-- Name: index_flight_schedules_on_route_summary; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_schedules_on_route_summary ON public.flight_schedules USING btree (route_summary);


--
-- Name: index_flight_schedules_on_verified_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_schedules_on_verified_by_id ON public.flight_schedules USING btree (verified_by_id);


--
-- Name: index_flight_tickets_on_schedule_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_tickets_on_schedule_id ON public.flight_tickets USING btree (schedule_id);


--
-- Name: index_flight_tickets_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_flight_tickets_on_traveler_id ON public.flight_tickets USING btree (traveler_id);


--
-- Name: index_fundraising_idea_images_on_display_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fundraising_idea_images_on_display_order ON public.fundraising_idea_images USING btree (display_order);


--
-- Name: index_fundraising_idea_images_on_fundraising_idea_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fundraising_idea_images_on_fundraising_idea_id ON public.fundraising_idea_images USING btree (fundraising_idea_id);


--
-- Name: index_fundraising_idea_images_on_hide; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_fundraising_idea_images_on_hide ON public.fundraising_idea_images USING btree (hide);


--
-- Name: index_import_athletes_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_athletes_on_school_id ON public.import_athletes USING btree (school_id);


--
-- Name: index_import_athletes_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_athletes_on_sport_id ON public.import_athletes USING btree (sport_id);


--
-- Name: index_import_athletes_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_athletes_on_state_id ON public.import_athletes USING btree (state_id);


--
-- Name: index_import_matches_on_school_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_matches_on_school_id ON public.import_matches USING btree (school_id);


--
-- Name: index_import_matches_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_import_matches_on_state_id ON public.import_matches USING btree (state_id);


--
-- Name: index_invite_rules_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invite_rules_on_sport_id ON public.invite_rules USING btree (sport_id);


--
-- Name: index_invite_rules_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_invite_rules_on_state_id ON public.invite_rules USING btree (state_id);


--
-- Name: index_mailings_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_mailings_on_user_id ON public.mailings USING btree (user_id);


--
-- Name: index_meeting_registrations_on_athlete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_registrations_on_athlete_id ON public.meeting_registrations USING btree (athlete_id);


--
-- Name: index_meeting_registrations_on_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_registrations_on_meeting_id ON public.meeting_registrations USING btree (meeting_id);


--
-- Name: index_meeting_registrations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_registrations_on_user_id ON public.meeting_registrations USING btree (user_id);


--
-- Name: index_meeting_video_views_on_athlete_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_video_views_on_athlete_id ON public.meeting_video_views USING btree (athlete_id);


--
-- Name: index_meeting_video_views_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_video_views_on_user_id ON public.meeting_video_views USING btree (user_id);


--
-- Name: index_meeting_video_views_on_video_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meeting_video_views_on_video_id ON public.meeting_video_views USING btree (video_id);


--
-- Name: index_meetings_on_host_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_host_id ON public.meetings USING btree (host_id);


--
-- Name: index_meetings_on_tech_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_tech_id ON public.meetings USING btree (tech_id);


--
-- Name: index_officials_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_officials_on_sport_id ON public.officials USING btree (sport_id);


--
-- Name: index_officials_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_officials_on_state_id ON public.officials USING btree (state_id);


--
-- Name: index_participants_on_category_and_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_participants_on_category_and_state_id ON public.participants USING btree (category, state_id);


--
-- Name: index_participants_on_gender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_participants_on_gender ON public.participants USING btree (gender);


--
-- Name: index_participants_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_participants_on_sport_id ON public.participants USING btree (sport_id);


--
-- Name: index_participants_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_participants_on_state_id ON public.participants USING btree (state_id);


--
-- Name: index_payment_items_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_items_on_payment_id ON public.payment_items USING btree (payment_id);


--
-- Name: index_payment_items_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_items_on_traveler_id ON public.payment_items USING btree (traveler_id);


--
-- Name: index_payment_join_terms_on_payment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_join_terms_on_payment_id ON public.payment_join_terms USING btree (payment_id);


--
-- Name: index_payment_remittances_on_reconciled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_remittances_on_reconciled ON public.payment_remittances USING btree (reconciled);


--
-- Name: index_payment_remittances_on_recorded; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_remittances_on_recorded ON public.payment_remittances USING btree (recorded);


--
-- Name: index_payment_remittances_on_remit_number; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_payment_remittances_on_remit_number ON public.payment_remittances USING btree (remit_number);


--
-- Name: index_payment_terms_on_edited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payment_terms_on_edited_by_id ON public.payment_terms USING btree (edited_by_id);


--
-- Name: index_payments_on_billing; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_billing ON public.payments USING gin (billing);


--
-- Name: index_payments_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_category ON public.payments USING hash (category);


--
-- Name: index_payments_on_category_and_successful; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_category_and_successful ON public.payments USING btree (category, successful);


--
-- Name: index_payments_on_gateway_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_gateway_type ON public.payments USING hash (gateway_type);


--
-- Name: index_payments_on_shirt_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_shirt_order_id ON public.payments USING btree (shirt_order_id);


--
-- Name: index_payments_on_successful_and_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_successful_and_category ON public.payments USING btree (successful, category);


--
-- Name: index_payments_on_transaction_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_transaction_id ON public.payments USING hash (transaction_id);


--
-- Name: index_payments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_payments_on_user_id ON public.payments USING btree (user_id);


--
-- Name: index_privacy_policies_on_edited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_privacy_policies_on_edited_by_id ON public.privacy_policies USING btree (edited_by_id);


--
-- Name: index_schools_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schools_on_address_id ON public.schools USING btree (address_id);


--
-- Name: index_schools_on_allowed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schools_on_allowed ON public.schools USING btree (allowed);


--
-- Name: index_schools_on_allowed_home; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schools_on_allowed_home ON public.schools USING btree (allowed_home);


--
-- Name: index_schools_on_closed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_schools_on_closed ON public.schools USING btree (closed);


--
-- Name: index_schools_on_pid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_schools_on_pid ON public.schools USING btree (pid);


--
-- Name: index_shirt_order_items_on_shirt_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shirt_order_items_on_shirt_order_id ON public.shirt_order_items USING btree (shirt_order_id);


--
-- Name: index_shirt_order_shipments_on_shirt_order_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_shirt_order_shipments_on_shirt_order_id ON public.shirt_order_shipments USING btree (shirt_order_id);


--
-- Name: index_sources_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sources_on_name ON public.sources USING btree (name);


--
-- Name: index_sport_events_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sport_events_on_sport_id ON public.sport_events USING btree (sport_id);


--
-- Name: index_sport_infos_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sport_infos_on_sport_id ON public.sport_infos USING btree (sport_id);


--
-- Name: index_sports_on_abbr; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sports_on_abbr ON public.sports USING btree (abbr);


--
-- Name: index_sports_on_abbr_gender; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sports_on_abbr_gender ON public.sports USING btree (abbr_gender);


--
-- Name: index_sports_on_full; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sports_on_full ON public.sports USING btree ("full");


--
-- Name: index_sports_on_full_gender; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sports_on_full_gender ON public.sports USING btree (full_gender);


--
-- Name: index_staff_assignment_visits_on_assignment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_assignment_visits_on_assignment_id ON public.staff_assignment_visits USING btree (assignment_id);


--
-- Name: index_staff_assignments_on_assigned_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_by_id ON public.staff_assignments USING btree (assigned_by_id);


--
-- Name: index_staff_assignments_on_assigned_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_to_id ON public.staff_assignments USING btree (assigned_to_id);


--
-- Name: index_staff_assignments_on_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_assignments_on_reason ON public.staff_assignments USING btree (reason);


--
-- Name: index_staff_assignments_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_assignments_on_user_id ON public.staff_assignments USING btree (user_id);


--
-- Name: index_staff_clocks_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_staff_clocks_on_staff_id ON public.staff_clocks USING btree (staff_id);


--
-- Name: index_states_on_abbr; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_states_on_abbr ON public.states USING btree (abbr);


--
-- Name: index_states_on_full; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_states_on_full ON public.states USING btree ("full");


--
-- Name: index_states_on_tz_offset; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_states_on_tz_offset ON public.states USING btree (tz_offset);


--
-- Name: index_student_lists_on_sent; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_student_lists_on_sent ON public.student_lists USING btree (sent);


--
-- Name: index_teams_on_competing_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_competing_team_id ON public.teams USING btree (competing_team_id);


--
-- Name: index_teams_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_sport_id ON public.teams USING btree (sport_id);


--
-- Name: index_teams_on_state_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_teams_on_state_id ON public.teams USING btree (state_id);


--
-- Name: index_thank_you_ticket_terms_on_edited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_thank_you_ticket_terms_on_edited_by_id ON public.thank_you_ticket_terms USING btree (edited_by_id);


--
-- Name: index_traveler_base_debits_on_is_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_base_debits_on_is_default ON public.traveler_base_debits USING btree (is_default);


--
-- Name: index_traveler_base_debits_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_base_debits_on_name ON public.traveler_base_debits USING gin (name);


--
-- Name: index_traveler_base_debits_on_name_and_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_base_debits_on_name_and_amount ON public.traveler_base_debits USING btree (name, amount);


--
-- Name: index_traveler_buses_on_color; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_on_color ON public.traveler_buses USING btree (color);


--
-- Name: index_traveler_buses_on_hotel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_on_hotel_id ON public.traveler_buses USING btree (hotel_id);


--
-- Name: index_traveler_buses_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_on_name ON public.traveler_buses USING btree (name);


--
-- Name: index_traveler_buses_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_on_sport_id ON public.traveler_buses USING btree (sport_id);


--
-- Name: index_traveler_buses_on_sport_id_and_color_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_on_sport_id_and_color_and_name ON public.traveler_buses USING btree (sport_id, color, name);


--
-- Name: index_traveler_buses_travelers_on_bus_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_bus_id ON public.traveler_buses_travelers USING btree (bus_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_traveler_id ON public.traveler_buses_travelers USING btree (traveler_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id_and_bus_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_travelers_on_traveler_id_and_bus_id ON public.traveler_buses_travelers USING btree (traveler_id, bus_id);


--
-- Name: index_traveler_credits_on_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_credits_on_amount ON public.traveler_credits USING btree (amount);


--
-- Name: index_traveler_credits_on_assigner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_credits_on_assigner_id ON public.traveler_credits USING btree (assigner_id);


--
-- Name: index_traveler_credits_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_credits_on_name ON public.traveler_credits USING gin (name);


--
-- Name: index_traveler_credits_on_name_and_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_credits_on_name_and_amount ON public.traveler_credits USING btree (name, amount);


--
-- Name: index_traveler_credits_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_credits_on_traveler_id ON public.traveler_credits USING btree (traveler_id);


--
-- Name: index_traveler_debits_on_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_debits_on_amount ON public.traveler_debits USING btree (amount);


--
-- Name: index_traveler_debits_on_assigner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_debits_on_assigner_id ON public.traveler_debits USING btree (assigner_id);


--
-- Name: index_traveler_debits_on_base_debit_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_debits_on_base_debit_id ON public.traveler_debits USING btree (base_debit_id);


--
-- Name: index_traveler_debits_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_debits_on_traveler_id ON public.traveler_debits USING btree (traveler_id);


--
-- Name: index_traveler_hotels_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_hotels_on_address_id ON public.traveler_hotels USING btree (address_id);


--
-- Name: index_traveler_offers_on_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_amount ON public.traveler_offers USING btree (amount);


--
-- Name: index_traveler_offers_on_assigner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_assigner_id ON public.traveler_offers USING btree (assigner_id);


--
-- Name: index_traveler_offers_on_maximum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_maximum ON public.traveler_offers USING btree (maximum);


--
-- Name: index_traveler_offers_on_minimum; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_minimum ON public.traveler_offers USING btree (minimum);


--
-- Name: index_traveler_offers_on_rules_and_amount; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_rules_and_amount ON public.traveler_offers USING btree ((rules[1]) text_pattern_ops, amount);


--
-- Name: index_traveler_offers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_offers_on_user_id ON public.traveler_offers USING btree (user_id);


--
-- Name: index_traveler_requests_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_requests_on_category ON public.traveler_requests USING btree (category);


--
-- Name: index_traveler_requests_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id ON public.traveler_requests USING btree (traveler_id);


--
-- Name: index_traveler_requests_on_traveler_id_and_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id_and_category ON public.traveler_requests USING btree (traveler_id, category);


--
-- Name: index_traveler_rooms_on_check_in_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_in_date ON public.traveler_rooms USING btree (check_in_date);


--
-- Name: index_traveler_rooms_on_check_out_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_out_date ON public.traveler_rooms USING btree (check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_traveler_rooms_on_hotel_dates ON public.traveler_rooms USING btree (traveler_id, hotel_id, check_in_date, check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_rooms_on_hotel_id ON public.traveler_rooms USING btree (hotel_id);


--
-- Name: index_traveler_rooms_on_traveler_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_traveler_rooms_on_traveler_id ON public.traveler_rooms USING btree (traveler_id);


--
-- Name: index_travelers_on_balance; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travelers_on_balance ON public.travelers USING btree (balance);


--
-- Name: index_travelers_on_cancel_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travelers_on_cancel_date ON public.travelers USING btree (cancel_date);


--
-- Name: index_travelers_on_departing_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travelers_on_departing_date ON public.travelers USING btree (departing_date);


--
-- Name: index_travelers_on_team_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_travelers_on_team_id ON public.travelers USING btree (team_id);


--
-- Name: index_travelers_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_travelers_on_user_id ON public.travelers USING btree (user_id);


--
-- Name: index_unsubscribers_on_category_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_unsubscribers_on_category_and_value ON public.unsubscribers USING btree (category, value);


--
-- Name: index_user_ambassadors_on_ambassador_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_ambassadors_on_ambassador_user_id ON public.user_ambassadors USING btree (ambassador_user_id);


--
-- Name: index_user_ambassadors_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_ambassadors_on_user_id ON public.user_ambassadors USING btree (user_id);


--
-- Name: index_user_event_registrations_on_submitter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_event_registrations_on_submitter_id ON public.user_event_registrations USING btree (submitter_id);


--
-- Name: index_user_event_registrations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_event_registrations_on_user_id ON public.user_event_registrations USING btree (user_id);


--
-- Name: index_user_forwarded_ids_on_dus_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_forwarded_ids_on_dus_id ON public.user_forwarded_ids USING btree (dus_id);


--
-- Name: index_user_forwarded_ids_on_original_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_forwarded_ids_on_original_id ON public.user_forwarded_ids USING btree (original_id);


--
-- Name: index_user_interest_histories_on_changed_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_interest_histories_on_changed_by_id ON public.user_interest_histories USING btree (changed_by_id);


--
-- Name: index_user_interest_histories_on_interest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_interest_histories_on_interest_id ON public.user_interest_histories USING btree (interest_id);


--
-- Name: index_user_interest_histories_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_interest_histories_on_user_id ON public.user_interest_histories USING btree (user_id);


--
-- Name: index_user_interest_histories_on_user_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_interest_histories_on_user_id_and_created_at ON public.user_interest_histories USING btree (user_id, created_at DESC);


--
-- Name: index_user_marathon_registrations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_marathon_registrations_on_user_id ON public.user_marathon_registrations USING btree (user_id);


--
-- Name: index_user_messages_on_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_category ON public.user_messages USING btree (category);


--
-- Name: index_user_messages_on_reason; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_reason ON public.user_messages USING btree (reason);


--
-- Name: index_user_messages_on_reviewed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_reviewed ON public.user_messages USING btree (reviewed);


--
-- Name: index_user_messages_on_staff_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_staff_id ON public.user_messages USING btree (staff_id);


--
-- Name: index_user_messages_on_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_type ON public.user_messages USING btree (type);


--
-- Name: index_user_messages_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_messages_on_user_id ON public.user_messages USING btree (user_id);


--
-- Name: index_user_nationalities_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_nationalities_on_code ON public.user_nationalities USING btree (code);


--
-- Name: index_user_overrides_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_overrides_on_user_id ON public.user_overrides USING btree (user_id);


--
-- Name: index_user_passport_authorities_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_user_passport_authorities_on_name ON public.user_passport_authorities USING btree (name);


--
-- Name: index_user_passports_on_checker_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_passports_on_checker_id ON public.user_passports USING btree (checker_id);


--
-- Name: index_user_passports_on_second_checker_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_passports_on_second_checker_id ON public.user_passports USING btree (second_checker_id);


--
-- Name: index_user_passports_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_passports_on_user_id ON public.user_passports USING btree (user_id);


--
-- Name: index_user_refund_requests_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_refund_requests_on_user_id ON public.user_refund_requests USING btree (user_id);


--
-- Name: index_user_relations_on_related_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_relations_on_related_user_id ON public.user_relations USING btree (related_user_id);


--
-- Name: index_user_relations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_relations_on_user_id ON public.user_relations USING btree (user_id);


--
-- Name: index_user_relationship_types_on_inverse_and_value; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_relationship_types_on_inverse_and_value ON public.user_relationship_types USING btree (inverse, value);


--
-- Name: index_user_relationship_types_on_value_and_inverse; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_relationship_types_on_value_and_inverse ON public.user_relationship_types USING btree (value, inverse);


--
-- Name: index_user_transfer_expectations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_transfer_expectations_on_user_id ON public.user_transfer_expectations USING btree (user_id);


--
-- Name: index_user_travel_preparations_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_travel_preparations_on_user_id ON public.user_travel_preparations USING btree (user_id);


--
-- Name: index_user_uniform_orders_on_sport_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_sport_id ON public.user_uniform_orders USING btree (sport_id);


--
-- Name: index_user_uniform_orders_on_submitter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_submitter_id ON public.user_uniform_orders USING btree (submitter_id);


--
-- Name: index_user_uniform_orders_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_user_id ON public.user_uniform_orders USING btree (user_id);


--
-- Name: index_users_on_address_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_address_id ON public.users USING btree (address_id);


--
-- Name: index_users_on_category_type_and_category_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_category_type_and_category_id ON public.users USING btree (category_type, category_id);


--
-- Name: index_users_on_dus_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_dus_id ON public.users USING btree (dus_id);


--
-- Name: index_users_on_gender; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_gender ON public.users USING btree (gender);


--
-- Name: index_users_on_interest_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_interest_id ON public.users USING btree (interest_id);


--
-- Name: index_users_on_responded_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_responded_at ON public.users USING btree (responded_at);


--
-- Name: index_users_on_visible_until_year; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_users_on_visible_until_year ON public.users USING btree (visible_until_year);


--
-- Name: index_view_trackers_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_view_trackers_on_name ON public.view_trackers USING btree (name);


--
-- Name: schools_name_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX schools_name_search_idx ON public.schools USING gin (name public.gin_trgm_ops);


--
-- Name: users_dus_id_hash_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_dus_id_hash_idx ON public.users USING hash (public.digest(dus_id, 'sha256'::text));


--
-- Name: users_first_name_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_first_name_search_idx ON public.users USING gin (first public.gin_trgm_ops);


--
-- Name: users_last_name_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_last_name_search_idx ON public.users USING gin (last public.gin_trgm_ops);


--
-- Name: users_print_first_names_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_print_first_names_search_idx ON public.users USING gin (print_first_names public.gin_trgm_ops);


--
-- Name: users_print_other_names_search_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX users_print_other_names_search_idx ON public.users USING gin (print_other_names public.gin_trgm_ops);


--
-- Name: expected_difficulty_and_status_index; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX expected_difficulty_and_status_index ON year_2019.user_transfer_expectations USING btree (difficulty, status);


--
-- Name: expected_status_and_difficulty_index; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX expected_status_and_difficulty_index ON year_2019.user_transfer_expectations USING btree (status, difficulty);


--
-- Name: expected_transfer_and_compete_index; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX expected_transfer_and_compete_index ON year_2019.user_transfer_expectations USING btree (can_transfer, can_compete);


--
-- Name: index_competing_teams_on_letter_and_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_letter_and_sport_id ON year_2019.competing_teams USING btree (letter, sport_id);


--
-- Name: index_competing_teams_on_name_and_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_name_and_sport_id ON year_2019.competing_teams USING btree (name, sport_id);


--
-- Name: index_competing_teams_on_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_competing_teams_on_sport_id ON year_2019.competing_teams USING btree (sport_id);


--
-- Name: index_competing_teams_travelers_on_competing_team_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_competing_team_id ON year_2019.competing_teams_travelers USING btree (competing_team_id);


--
-- Name: index_competing_teams_travelers_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_traveler_id ON year_2019.competing_teams_travelers USING btree (traveler_id);


--
-- Name: index_flight_legs_on_arriving_airport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_legs_on_arriving_airport_id ON year_2019.flight_legs USING btree (arriving_airport_id);


--
-- Name: index_flight_legs_on_departing_airport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_legs_on_departing_airport_id ON year_2019.flight_legs USING btree (departing_airport_id);


--
-- Name: index_flight_legs_on_schedule_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_legs_on_schedule_id ON year_2019.flight_legs USING btree (schedule_id);


--
-- Name: index_flight_schedules_on_parent_schedule_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_schedules_on_parent_schedule_id ON year_2019.flight_schedules USING btree (parent_schedule_id);


--
-- Name: index_flight_schedules_on_pnr; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_flight_schedules_on_pnr ON year_2019.flight_schedules USING btree (pnr);


--
-- Name: index_flight_schedules_on_route_summary; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_schedules_on_route_summary ON year_2019.flight_schedules USING btree (route_summary);


--
-- Name: index_flight_schedules_on_verified_by_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_schedules_on_verified_by_id ON year_2019.flight_schedules USING btree (verified_by_id);


--
-- Name: index_flight_tickets_on_schedule_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_tickets_on_schedule_id ON year_2019.flight_tickets USING btree (schedule_id);


--
-- Name: index_flight_tickets_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_flight_tickets_on_traveler_id ON year_2019.flight_tickets USING btree (traveler_id);


--
-- Name: index_mailings_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_mailings_on_user_id ON year_2019.mailings USING btree (user_id);


--
-- Name: index_meeting_registrations_on_athlete_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_registrations_on_athlete_id ON year_2019.meeting_registrations USING btree (athlete_id);


--
-- Name: index_meeting_registrations_on_meeting_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_registrations_on_meeting_id ON year_2019.meeting_registrations USING btree (meeting_id);


--
-- Name: index_meeting_registrations_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_registrations_on_user_id ON year_2019.meeting_registrations USING btree (user_id);


--
-- Name: index_meeting_video_views_on_athlete_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_video_views_on_athlete_id ON year_2019.meeting_video_views USING btree (athlete_id);


--
-- Name: index_meeting_video_views_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_video_views_on_user_id ON year_2019.meeting_video_views USING btree (user_id);


--
-- Name: index_meeting_video_views_on_video_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_meeting_video_views_on_video_id ON year_2019.meeting_video_views USING btree (video_id);


--
-- Name: index_payment_items_on_payment_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payment_items_on_payment_id ON year_2019.payment_items USING btree (payment_id);


--
-- Name: index_payment_items_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payment_items_on_traveler_id ON year_2019.payment_items USING btree (traveler_id);


--
-- Name: index_payment_join_terms_on_payment_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payment_join_terms_on_payment_id ON year_2019.payment_join_terms USING btree (payment_id);


--
-- Name: index_payment_remittances_on_reconciled; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payment_remittances_on_reconciled ON year_2019.payment_remittances USING btree (reconciled);


--
-- Name: index_payment_remittances_on_recorded; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payment_remittances_on_recorded ON year_2019.payment_remittances USING btree (recorded);


--
-- Name: index_payment_remittances_on_remit_number; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_payment_remittances_on_remit_number ON year_2019.payment_remittances USING btree (remit_number);


--
-- Name: index_payments_on_billing; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_billing ON year_2019.payments USING gin (billing);


--
-- Name: index_payments_on_category; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_category ON year_2019.payments USING hash (category);


--
-- Name: index_payments_on_category_and_successful; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_category_and_successful ON year_2019.payments USING btree (category, successful);


--
-- Name: index_payments_on_gateway_type; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_gateway_type ON year_2019.payments USING hash (gateway_type);


--
-- Name: index_payments_on_shirt_order_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_shirt_order_id ON year_2019.payments USING btree (shirt_order_id);


--
-- Name: index_payments_on_successful_and_category; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_successful_and_category ON year_2019.payments USING btree (successful, category);


--
-- Name: index_payments_on_transaction_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_transaction_id ON year_2019.payments USING hash (transaction_id);


--
-- Name: index_payments_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_payments_on_user_id ON year_2019.payments USING btree (user_id);


--
-- Name: index_staff_assignment_visits_on_assignment_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_staff_assignment_visits_on_assignment_id ON year_2019.staff_assignment_visits USING btree (assignment_id);


--
-- Name: index_staff_assignments_on_assigned_by_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_by_id ON year_2019.staff_assignments USING btree (assigned_by_id);


--
-- Name: index_staff_assignments_on_assigned_to_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_to_id ON year_2019.staff_assignments USING btree (assigned_to_id);


--
-- Name: index_staff_assignments_on_reason; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_staff_assignments_on_reason ON year_2019.staff_assignments USING btree (reason);


--
-- Name: index_staff_assignments_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_staff_assignments_on_user_id ON year_2019.staff_assignments USING btree (user_id);


--
-- Name: index_student_lists_on_sent; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_student_lists_on_sent ON year_2019.student_lists USING btree (sent);


--
-- Name: index_teams_on_competing_team_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_teams_on_competing_team_id ON year_2019.teams USING btree (competing_team_id);


--
-- Name: index_teams_on_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_teams_on_sport_id ON year_2019.teams USING btree (sport_id);


--
-- Name: index_teams_on_state_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_teams_on_state_id ON year_2019.teams USING btree (state_id);


--
-- Name: index_traveler_buses_on_color; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_on_color ON year_2019.traveler_buses USING btree (color);


--
-- Name: index_traveler_buses_on_hotel_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_on_hotel_id ON year_2019.traveler_buses USING btree (hotel_id);


--
-- Name: index_traveler_buses_on_name; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_on_name ON year_2019.traveler_buses USING btree (name);


--
-- Name: index_traveler_buses_on_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_on_sport_id ON year_2019.traveler_buses USING btree (sport_id);


--
-- Name: index_traveler_buses_on_sport_id_and_color_and_name; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_on_sport_id_and_color_and_name ON year_2019.traveler_buses USING btree (sport_id, color, name);


--
-- Name: index_traveler_buses_travelers_on_bus_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_bus_id ON year_2019.traveler_buses_travelers USING btree (bus_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_traveler_id ON year_2019.traveler_buses_travelers USING btree (traveler_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id_and_bus_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_travelers_on_traveler_id_and_bus_id ON year_2019.traveler_buses_travelers USING btree (traveler_id, bus_id);


--
-- Name: index_traveler_credits_on_amount; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_credits_on_amount ON year_2019.traveler_credits USING btree (amount);


--
-- Name: index_traveler_credits_on_assigner_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_credits_on_assigner_id ON year_2019.traveler_credits USING btree (assigner_id);


--
-- Name: index_traveler_credits_on_name; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_credits_on_name ON year_2019.traveler_credits USING gin (name);


--
-- Name: index_traveler_credits_on_name_and_amount; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_credits_on_name_and_amount ON year_2019.traveler_credits USING btree (name, amount);


--
-- Name: index_traveler_credits_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_credits_on_traveler_id ON year_2019.traveler_credits USING btree (traveler_id);


--
-- Name: index_traveler_debits_on_amount; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_debits_on_amount ON year_2019.traveler_debits USING btree (amount);


--
-- Name: index_traveler_debits_on_assigner_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_debits_on_assigner_id ON year_2019.traveler_debits USING btree (assigner_id);


--
-- Name: index_traveler_debits_on_base_debit_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_debits_on_base_debit_id ON year_2019.traveler_debits USING btree (base_debit_id);


--
-- Name: index_traveler_debits_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_debits_on_traveler_id ON year_2019.traveler_debits USING btree (traveler_id);


--
-- Name: index_traveler_offers_on_amount; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_amount ON year_2019.traveler_offers USING btree (amount);


--
-- Name: index_traveler_offers_on_assigner_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_assigner_id ON year_2019.traveler_offers USING btree (assigner_id);


--
-- Name: index_traveler_offers_on_maximum; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_maximum ON year_2019.traveler_offers USING btree (maximum);


--
-- Name: index_traveler_offers_on_minimum; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_minimum ON year_2019.traveler_offers USING btree (minimum);


--
-- Name: index_traveler_offers_on_rules_and_amount; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_rules_and_amount ON year_2019.traveler_offers USING btree ((rules[1]) text_pattern_ops, amount);


--
-- Name: index_traveler_offers_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_offers_on_user_id ON year_2019.traveler_offers USING btree (user_id);


--
-- Name: index_traveler_requests_on_category; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_requests_on_category ON year_2019.traveler_requests USING btree (category);


--
-- Name: index_traveler_requests_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id ON year_2019.traveler_requests USING btree (traveler_id);


--
-- Name: index_traveler_requests_on_traveler_id_and_category; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id_and_category ON year_2019.traveler_requests USING btree (traveler_id, category);


--
-- Name: index_traveler_rooms_on_check_in_date; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_in_date ON year_2019.traveler_rooms USING btree (check_in_date);


--
-- Name: index_traveler_rooms_on_check_out_date; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_out_date ON year_2019.traveler_rooms USING btree (check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_dates; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_traveler_rooms_on_hotel_dates ON year_2019.traveler_rooms USING btree (traveler_id, hotel_id, check_in_date, check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_rooms_on_hotel_id ON year_2019.traveler_rooms USING btree (hotel_id);


--
-- Name: index_traveler_rooms_on_traveler_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_traveler_rooms_on_traveler_id ON year_2019.traveler_rooms USING btree (traveler_id);


--
-- Name: index_travelers_on_balance; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_travelers_on_balance ON year_2019.travelers USING btree (balance);


--
-- Name: index_travelers_on_cancel_date; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_travelers_on_cancel_date ON year_2019.travelers USING btree (cancel_date);


--
-- Name: index_travelers_on_departing_date; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_travelers_on_departing_date ON year_2019.travelers USING btree (departing_date);


--
-- Name: index_travelers_on_team_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_travelers_on_team_id ON year_2019.travelers USING btree (team_id);


--
-- Name: index_travelers_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE UNIQUE INDEX index_travelers_on_user_id ON year_2019.travelers USING btree (user_id);


--
-- Name: index_user_event_registrations_on_submitter_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_event_registrations_on_submitter_id ON year_2019.user_event_registrations USING btree (submitter_id);


--
-- Name: index_user_event_registrations_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_event_registrations_on_user_id ON year_2019.user_event_registrations USING btree (user_id);


--
-- Name: index_user_marathon_registrations_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_marathon_registrations_on_user_id ON year_2019.user_marathon_registrations USING btree (user_id);


--
-- Name: index_user_messages_on_category; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_category ON year_2019.user_messages USING btree (category);


--
-- Name: index_user_messages_on_reason; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_reason ON year_2019.user_messages USING btree (reason);


--
-- Name: index_user_messages_on_reviewed; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_reviewed ON year_2019.user_messages USING btree (reviewed);


--
-- Name: index_user_messages_on_staff_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_staff_id ON year_2019.user_messages USING btree (staff_id);


--
-- Name: index_user_messages_on_type; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_type ON year_2019.user_messages USING btree (type);


--
-- Name: index_user_messages_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_messages_on_user_id ON year_2019.user_messages USING btree (user_id);


--
-- Name: index_user_overrides_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_overrides_on_user_id ON year_2019.user_overrides USING btree (user_id);


--
-- Name: index_user_transfer_expectations_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_transfer_expectations_on_user_id ON year_2019.user_transfer_expectations USING btree (user_id);


--
-- Name: index_user_travel_preparations_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_travel_preparations_on_user_id ON year_2019.user_travel_preparations USING btree (user_id);


--
-- Name: index_user_uniform_orders_on_sport_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_sport_id ON year_2019.user_uniform_orders USING btree (sport_id);


--
-- Name: index_user_uniform_orders_on_submitter_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_submitter_id ON year_2019.user_uniform_orders USING btree (submitter_id);


--
-- Name: index_user_uniform_orders_on_user_id; Type: INDEX; Schema: year_2019; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_user_id ON year_2019.user_uniform_orders USING btree (user_id);


--
-- Name: expected_difficulty_and_status_index; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX expected_difficulty_and_status_index ON year_2020.user_transfer_expectations USING btree (difficulty, status);


--
-- Name: expected_status_and_difficulty_index; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX expected_status_and_difficulty_index ON year_2020.user_transfer_expectations USING btree (status, difficulty);


--
-- Name: expected_transfer_and_compete_index; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX expected_transfer_and_compete_index ON year_2020.user_transfer_expectations USING btree (can_transfer, can_compete);


--
-- Name: index_competing_teams_on_letter_and_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_letter_and_sport_id ON year_2020.competing_teams USING btree (letter, sport_id);


--
-- Name: index_competing_teams_on_name_and_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_competing_teams_on_name_and_sport_id ON year_2020.competing_teams USING btree (name, sport_id);


--
-- Name: index_competing_teams_on_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_competing_teams_on_sport_id ON year_2020.competing_teams USING btree (sport_id);


--
-- Name: index_competing_teams_travelers_on_competing_team_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_competing_team_id ON year_2020.competing_teams_travelers USING btree (competing_team_id);


--
-- Name: index_competing_teams_travelers_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_competing_teams_travelers_on_traveler_id ON year_2020.competing_teams_travelers USING btree (traveler_id);


--
-- Name: index_flight_legs_on_arriving_airport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_legs_on_arriving_airport_id ON year_2020.flight_legs USING btree (arriving_airport_id);


--
-- Name: index_flight_legs_on_departing_airport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_legs_on_departing_airport_id ON year_2020.flight_legs USING btree (departing_airport_id);


--
-- Name: index_flight_legs_on_schedule_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_legs_on_schedule_id ON year_2020.flight_legs USING btree (schedule_id);


--
-- Name: index_flight_schedules_on_parent_schedule_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_schedules_on_parent_schedule_id ON year_2020.flight_schedules USING btree (parent_schedule_id);


--
-- Name: index_flight_schedules_on_pnr; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_flight_schedules_on_pnr ON year_2020.flight_schedules USING btree (pnr);


--
-- Name: index_flight_schedules_on_route_summary; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_schedules_on_route_summary ON year_2020.flight_schedules USING btree (route_summary);


--
-- Name: index_flight_schedules_on_verified_by_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_schedules_on_verified_by_id ON year_2020.flight_schedules USING btree (verified_by_id);


--
-- Name: index_flight_tickets_on_schedule_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_tickets_on_schedule_id ON year_2020.flight_tickets USING btree (schedule_id);


--
-- Name: index_flight_tickets_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_flight_tickets_on_traveler_id ON year_2020.flight_tickets USING btree (traveler_id);


--
-- Name: index_mailings_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_mailings_on_user_id ON year_2020.mailings USING btree (user_id);


--
-- Name: index_meeting_registrations_on_athlete_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_registrations_on_athlete_id ON year_2020.meeting_registrations USING btree (athlete_id);


--
-- Name: index_meeting_registrations_on_meeting_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_registrations_on_meeting_id ON year_2020.meeting_registrations USING btree (meeting_id);


--
-- Name: index_meeting_registrations_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_registrations_on_user_id ON year_2020.meeting_registrations USING btree (user_id);


--
-- Name: index_meeting_video_views_on_athlete_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_video_views_on_athlete_id ON year_2020.meeting_video_views USING btree (athlete_id);


--
-- Name: index_meeting_video_views_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_video_views_on_user_id ON year_2020.meeting_video_views USING btree (user_id);


--
-- Name: index_meeting_video_views_on_video_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_meeting_video_views_on_video_id ON year_2020.meeting_video_views USING btree (video_id);


--
-- Name: index_payment_items_on_payment_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payment_items_on_payment_id ON year_2020.payment_items USING btree (payment_id);


--
-- Name: index_payment_items_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payment_items_on_traveler_id ON year_2020.payment_items USING btree (traveler_id);


--
-- Name: index_payment_join_terms_on_payment_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payment_join_terms_on_payment_id ON year_2020.payment_join_terms USING btree (payment_id);


--
-- Name: index_payment_remittances_on_reconciled; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payment_remittances_on_reconciled ON year_2020.payment_remittances USING btree (reconciled);


--
-- Name: index_payment_remittances_on_recorded; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payment_remittances_on_recorded ON year_2020.payment_remittances USING btree (recorded);


--
-- Name: index_payment_remittances_on_remit_number; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_payment_remittances_on_remit_number ON year_2020.payment_remittances USING btree (remit_number);


--
-- Name: index_payments_on_billing; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_billing ON year_2020.payments USING gin (billing);


--
-- Name: index_payments_on_category; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_category ON year_2020.payments USING hash (category);


--
-- Name: index_payments_on_category_and_successful; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_category_and_successful ON year_2020.payments USING btree (category, successful);


--
-- Name: index_payments_on_gateway_type; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_gateway_type ON year_2020.payments USING hash (gateway_type);


--
-- Name: index_payments_on_shirt_order_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_shirt_order_id ON year_2020.payments USING btree (shirt_order_id);


--
-- Name: index_payments_on_successful_and_category; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_successful_and_category ON year_2020.payments USING btree (successful, category);


--
-- Name: index_payments_on_transaction_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_transaction_id ON year_2020.payments USING hash (transaction_id);


--
-- Name: index_payments_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_payments_on_user_id ON year_2020.payments USING btree (user_id);


--
-- Name: index_staff_assignment_visits_on_assignment_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_staff_assignment_visits_on_assignment_id ON year_2020.staff_assignment_visits USING btree (assignment_id);


--
-- Name: index_staff_assignments_on_assigned_by_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_by_id ON year_2020.staff_assignments USING btree (assigned_by_id);


--
-- Name: index_staff_assignments_on_assigned_to_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_staff_assignments_on_assigned_to_id ON year_2020.staff_assignments USING btree (assigned_to_id);


--
-- Name: index_staff_assignments_on_reason; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_staff_assignments_on_reason ON year_2020.staff_assignments USING btree (reason);


--
-- Name: index_staff_assignments_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_staff_assignments_on_user_id ON year_2020.staff_assignments USING btree (user_id);


--
-- Name: index_student_lists_on_sent; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_student_lists_on_sent ON year_2020.student_lists USING btree (sent);


--
-- Name: index_teams_on_competing_team_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_teams_on_competing_team_id ON year_2020.teams USING btree (competing_team_id);


--
-- Name: index_teams_on_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_teams_on_sport_id ON year_2020.teams USING btree (sport_id);


--
-- Name: index_teams_on_state_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_teams_on_state_id ON year_2020.teams USING btree (state_id);


--
-- Name: index_traveler_buses_on_color; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_on_color ON year_2020.traveler_buses USING btree (color);


--
-- Name: index_traveler_buses_on_hotel_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_on_hotel_id ON year_2020.traveler_buses USING btree (hotel_id);


--
-- Name: index_traveler_buses_on_name; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_on_name ON year_2020.traveler_buses USING btree (name);


--
-- Name: index_traveler_buses_on_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_on_sport_id ON year_2020.traveler_buses USING btree (sport_id);


--
-- Name: index_traveler_buses_on_sport_id_and_color_and_name; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_on_sport_id_and_color_and_name ON year_2020.traveler_buses USING btree (sport_id, color, name);


--
-- Name: index_traveler_buses_travelers_on_bus_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_bus_id ON year_2020.traveler_buses_travelers USING btree (bus_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_buses_travelers_on_traveler_id ON year_2020.traveler_buses_travelers USING btree (traveler_id);


--
-- Name: index_traveler_buses_travelers_on_traveler_id_and_bus_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_traveler_buses_travelers_on_traveler_id_and_bus_id ON year_2020.traveler_buses_travelers USING btree (traveler_id, bus_id);


--
-- Name: index_traveler_credits_on_amount; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_credits_on_amount ON year_2020.traveler_credits USING btree (amount);


--
-- Name: index_traveler_credits_on_assigner_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_credits_on_assigner_id ON year_2020.traveler_credits USING btree (assigner_id);


--
-- Name: index_traveler_credits_on_name; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_credits_on_name ON year_2020.traveler_credits USING gin (name);


--
-- Name: index_traveler_credits_on_name_and_amount; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_credits_on_name_and_amount ON year_2020.traveler_credits USING btree (name, amount);


--
-- Name: index_traveler_credits_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_credits_on_traveler_id ON year_2020.traveler_credits USING btree (traveler_id);


--
-- Name: index_traveler_debits_on_amount; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_debits_on_amount ON year_2020.traveler_debits USING btree (amount);


--
-- Name: index_traveler_debits_on_assigner_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_debits_on_assigner_id ON year_2020.traveler_debits USING btree (assigner_id);


--
-- Name: index_traveler_debits_on_base_debit_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_debits_on_base_debit_id ON year_2020.traveler_debits USING btree (base_debit_id);


--
-- Name: index_traveler_debits_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_debits_on_traveler_id ON year_2020.traveler_debits USING btree (traveler_id);


--
-- Name: index_traveler_offers_on_amount; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_amount ON year_2020.traveler_offers USING btree (amount);


--
-- Name: index_traveler_offers_on_assigner_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_assigner_id ON year_2020.traveler_offers USING btree (assigner_id);


--
-- Name: index_traveler_offers_on_maximum; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_maximum ON year_2020.traveler_offers USING btree (maximum);


--
-- Name: index_traveler_offers_on_minimum; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_minimum ON year_2020.traveler_offers USING btree (minimum);


--
-- Name: index_traveler_offers_on_rules_and_amount; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_rules_and_amount ON year_2020.traveler_offers USING btree ((rules[1]) text_pattern_ops, amount);


--
-- Name: index_traveler_offers_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_offers_on_user_id ON year_2020.traveler_offers USING btree (user_id);


--
-- Name: index_traveler_requests_on_category; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_requests_on_category ON year_2020.traveler_requests USING btree (category);


--
-- Name: index_traveler_requests_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id ON year_2020.traveler_requests USING btree (traveler_id);


--
-- Name: index_traveler_requests_on_traveler_id_and_category; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_requests_on_traveler_id_and_category ON year_2020.traveler_requests USING btree (traveler_id, category);


--
-- Name: index_traveler_rooms_on_check_in_date; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_in_date ON year_2020.traveler_rooms USING btree (check_in_date);


--
-- Name: index_traveler_rooms_on_check_out_date; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_rooms_on_check_out_date ON year_2020.traveler_rooms USING btree (check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_dates; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_traveler_rooms_on_hotel_dates ON year_2020.traveler_rooms USING btree (traveler_id, hotel_id, check_in_date, check_out_date);


--
-- Name: index_traveler_rooms_on_hotel_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_rooms_on_hotel_id ON year_2020.traveler_rooms USING btree (hotel_id);


--
-- Name: index_traveler_rooms_on_traveler_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_traveler_rooms_on_traveler_id ON year_2020.traveler_rooms USING btree (traveler_id);


--
-- Name: index_travelers_on_balance; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_travelers_on_balance ON year_2020.travelers USING btree (balance);


--
-- Name: index_travelers_on_cancel_date; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_travelers_on_cancel_date ON year_2020.travelers USING btree (cancel_date);


--
-- Name: index_travelers_on_departing_date; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_travelers_on_departing_date ON year_2020.travelers USING btree (departing_date);


--
-- Name: index_travelers_on_team_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_travelers_on_team_id ON year_2020.travelers USING btree (team_id);


--
-- Name: index_travelers_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE UNIQUE INDEX index_travelers_on_user_id ON year_2020.travelers USING btree (user_id);


--
-- Name: index_user_event_registrations_on_submitter_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_event_registrations_on_submitter_id ON year_2020.user_event_registrations USING btree (submitter_id);


--
-- Name: index_user_event_registrations_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_event_registrations_on_user_id ON year_2020.user_event_registrations USING btree (user_id);


--
-- Name: index_user_marathon_registrations_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_marathon_registrations_on_user_id ON year_2020.user_marathon_registrations USING btree (user_id);


--
-- Name: index_user_messages_on_category; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_category ON year_2020.user_messages USING btree (category);


--
-- Name: index_user_messages_on_reason; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_reason ON year_2020.user_messages USING btree (reason);


--
-- Name: index_user_messages_on_reviewed; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_reviewed ON year_2020.user_messages USING btree (reviewed);


--
-- Name: index_user_messages_on_staff_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_staff_id ON year_2020.user_messages USING btree (staff_id);


--
-- Name: index_user_messages_on_type; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_type ON year_2020.user_messages USING btree (type);


--
-- Name: index_user_messages_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_messages_on_user_id ON year_2020.user_messages USING btree (user_id);


--
-- Name: index_user_overrides_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_overrides_on_user_id ON year_2020.user_overrides USING btree (user_id);


--
-- Name: index_user_transfer_expectations_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_transfer_expectations_on_user_id ON year_2020.user_transfer_expectations USING btree (user_id);


--
-- Name: index_user_travel_preparations_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_travel_preparations_on_user_id ON year_2020.user_travel_preparations USING btree (user_id);


--
-- Name: index_user_uniform_orders_on_sport_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_sport_id ON year_2020.user_uniform_orders USING btree (sport_id);


--
-- Name: index_user_uniform_orders_on_submitter_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_submitter_id ON year_2020.user_uniform_orders USING btree (submitter_id);


--
-- Name: index_user_uniform_orders_on_user_id; Type: INDEX; Schema: year_2020; Owner: -
--

CREATE INDEX index_user_uniform_orders_on_user_id ON year_2020.user_uniform_orders USING btree (user_id);


--
-- Name: logged_actions_view logged_actions_partition_by_table; Type: TRIGGER; Schema: auditing; Owner: -
--

CREATE TRIGGER logged_actions_partition_by_table INSTEAD OF INSERT ON auditing.logged_actions_view FOR EACH ROW EXECUTE FUNCTION auditing.logged_actions_partition();


--
-- Name: logged_actions logged_actions_skip_direct; Type: TRIGGER; Schema: auditing; Owner: -
--

CREATE TRIGGER logged_actions_skip_direct BEFORE INSERT ON auditing.logged_actions FOR EACH STATEMENT EXECUTE FUNCTION auditing.skip_logged_actions_main();


--
-- Name: active_storage_attachments audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.active_storage_attachments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: active_storage_blobs audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.active_storage_blobs FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: addresses audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.addresses FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: athletes audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.athletes FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: athletes_sports audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.athletes_sports FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: coaches audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.coaches FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: event_result_static_files audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.event_result_static_files FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: event_results audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.event_results FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_airports audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.flight_airports FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meeting_videos audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.meeting_videos FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meetings audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.meetings FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: officials audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.officials FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: schools audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.schools FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: shirt_order_items audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.shirt_order_items FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: shirt_order_shipments audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.shirt_order_shipments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: shirt_orders audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.shirt_orders FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: sources audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.sources FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: sports audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.sports FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: staffs audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.staffs FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: states audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.states FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_base_debits audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.traveler_base_debits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_hotels audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.traveler_hotels FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_ambassadors audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.user_ambassadors FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_relations audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.user_relations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: users audit_trigger_row; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('false', 'id', '{password,register_secret,certificate,updated_at}');


--
-- Name: active_storage_attachments audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.active_storage_attachments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: active_storage_blobs audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.active_storage_blobs FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: addresses audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.addresses FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: athletes audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.athletes FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: athletes_sports audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.athletes_sports FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: coaches audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.coaches FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: event_result_static_files audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.event_result_static_files FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: event_results audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.event_results FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_airports audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.flight_airports FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meeting_videos audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.meeting_videos FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meetings audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.meetings FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: officials audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.officials FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: schools audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.schools FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: shirt_order_items audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.shirt_order_items FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: shirt_order_shipments audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.shirt_order_shipments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: shirt_orders audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.shirt_orders FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: sources audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.sources FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: sports audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.sports FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: staffs audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.staffs FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: states audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.states FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_base_debits audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.traveler_base_debits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_hotels audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.traveler_hotels FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_ambassadors audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.user_ambassadors FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_relations audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.user_relations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: users audit_trigger_stm; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON public.users FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('false');


--
-- Name: competing_teams competing_teams_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER competing_teams_skip_direct BEFORE INSERT ON public.competing_teams FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: competing_teams_travelers competing_teams_travelers_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER competing_teams_travelers_skip_direct BEFORE INSERT ON public.competing_teams_travelers FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: flight_legs flight_legs_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER flight_legs_skip_direct BEFORE INSERT ON public.flight_legs FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: flight_schedules flight_schedules_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER flight_schedules_skip_direct BEFORE INSERT ON public.flight_schedules FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: flight_tickets flight_tickets_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER flight_tickets_skip_direct BEFORE INSERT ON public.flight_tickets FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: mailings mailings_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER mailings_skip_direct BEFORE INSERT ON public.mailings FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: meeting_registrations meeting_registrations_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meeting_registrations_skip_direct BEFORE INSERT ON public.meeting_registrations FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: meeting_video_views meeting_video_views_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER meeting_video_views_skip_direct BEFORE INSERT ON public.meeting_video_views FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: payment_items payment_items_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_items_skip_direct BEFORE INSERT ON public.payment_items FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: payment_remittances payment_remittances_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payment_remittances_skip_direct BEFORE INSERT ON public.payment_remittances FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: payments payments_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER payments_skip_direct BEFORE INSERT ON public.payments FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: user_relationship_types relationship_type_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER relationship_type_insert AFTER INSERT ON public.user_relationship_types FOR EACH ROW EXECUTE FUNCTION public.relationship_type_insert();


--
-- Name: user_relationship_types relationship_type_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER relationship_type_update AFTER UPDATE ON public.user_relationship_types FOR EACH ROW EXECUTE FUNCTION public.relationship_type_update();


--
-- Name: sent_mails sent_mails_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sent_mails_skip_direct BEFORE INSERT ON public.sent_mails FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: staff_assignment_visits staff_assignment_visits_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER staff_assignment_visits_skip_direct BEFORE INSERT ON public.staff_assignment_visits FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: staff_assignments staff_assignments_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER staff_assignments_skip_direct BEFORE INSERT ON public.staff_assignments FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: student_lists student_lists_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER student_lists_skip_direct BEFORE INSERT ON public.student_lists FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: teams teams_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER teams_skip_direct BEFORE INSERT ON public.teams FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_buses traveler_buses_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_buses_skip_direct BEFORE INSERT ON public.traveler_buses FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_buses_travelers traveler_buses_travelers_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_buses_travelers_skip_direct BEFORE INSERT ON public.traveler_buses_travelers FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_credits traveler_credits_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_credits_skip_direct BEFORE INSERT ON public.traveler_credits FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_debits traveler_debits_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_debits_skip_direct BEFORE INSERT ON public.traveler_debits FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_offers traveler_offers_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_offers_skip_direct BEFORE INSERT ON public.traveler_offers FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: traveler_rooms traveler_rooms_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER traveler_rooms_skip_direct BEFORE INSERT ON public.traveler_rooms FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: travelers travelers_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER travelers_skip_direct BEFORE INSERT ON public.travelers FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: user_event_registrations user_event_registrations_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_event_registrations_skip_direct BEFORE INSERT ON public.user_event_registrations FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: users user_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_insert BEFORE INSERT OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.valid_email_trigger();


--
-- Name: user_marathon_registrations user_marathon_registrations_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_marathon_registrations_skip_direct BEFORE INSERT ON public.user_marathon_registrations FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: user_messages user_messages_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_messages_skip_direct BEFORE INSERT ON public.user_messages FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: user_overrides user_overrides_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_overrides_skip_direct BEFORE INSERT ON public.user_overrides FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: user_uniform_orders user_uniform_orders_skip_direct; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER user_uniform_orders_skip_direct BEFORE INSERT ON public.user_uniform_orders FOR EACH STATEMENT EXECUTE FUNCTION public.bad_insert_on_parent_table();


--
-- Name: users users_on_insert; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER users_on_insert BEFORE INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_changed();


--
-- Name: users users_on_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER users_on_update BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.user_changed();


--
-- Name: competing_teams audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.competing_teams FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: competing_teams_travelers audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.competing_teams_travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_legs audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.flight_legs FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_schedules audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.flight_schedules FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_tickets audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.flight_tickets FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: mailings audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.mailings FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meeting_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.meeting_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meeting_video_views audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.meeting_video_views FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payment_items audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.payment_items FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payment_remittances audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.payment_remittances FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payments audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.payments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: sent_mails audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.sent_mails FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: staff_assignment_visits audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.staff_assignment_visits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: staff_assignments audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.staff_assignments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: student_lists audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.student_lists FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: teams audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.teams FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_buses audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_buses FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_buses_travelers audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_buses_travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'null', '{updated_at}');


--
-- Name: traveler_credits audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_credits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_debits audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_debits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_offers audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_offers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_rooms audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.traveler_rooms FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: travelers audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_event_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_event_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_marathon_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_marathon_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_messages audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_messages FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_overrides audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_overrides FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_transfer_expectations audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_transfer_expectations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_travel_preparations audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_travel_preparations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_uniform_orders audit_trigger_row; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2019.user_uniform_orders FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: competing_teams audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.competing_teams FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: competing_teams_travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.competing_teams_travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_legs audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.flight_legs FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_schedules audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.flight_schedules FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_tickets audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.flight_tickets FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: mailings audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.mailings FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meeting_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.meeting_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meeting_video_views audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.meeting_video_views FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payment_items audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.payment_items FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payment_remittances audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.payment_remittances FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payments audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.payments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: sent_mails audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.sent_mails FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: staff_assignment_visits audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.staff_assignment_visits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: staff_assignments audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.staff_assignments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: student_lists audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.student_lists FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: teams audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.teams FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_buses audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_buses FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_buses_travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_buses_travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_credits audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_credits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_debits audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_debits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_offers audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_offers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_rooms audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.traveler_rooms FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_event_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_event_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_marathon_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_marathon_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_messages audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_messages FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_overrides audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_overrides FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_transfer_expectations audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_transfer_expectations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_travel_preparations audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_travel_preparations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_uniform_orders audit_trigger_stm; Type: TRIGGER; Schema: year_2019; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2019.user_uniform_orders FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: competing_teams audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.competing_teams FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: competing_teams_travelers audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.competing_teams_travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_legs audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.flight_legs FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_schedules audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.flight_schedules FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: flight_tickets audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.flight_tickets FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: mailings audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.mailings FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meeting_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.meeting_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: meeting_video_views audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.meeting_video_views FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payment_items audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.payment_items FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payment_remittances audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.payment_remittances FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: payments audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.payments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: sent_mails audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.sent_mails FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: staff_assignment_visits audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.staff_assignment_visits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: staff_assignments audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.staff_assignments FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: student_lists audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.student_lists FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: teams audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.teams FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_buses audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_buses FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_buses_travelers audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_buses_travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'null', '{updated_at}');


--
-- Name: traveler_credits audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_credits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_debits audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_debits FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_offers audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_offers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: traveler_rooms audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.traveler_rooms FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: travelers audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.travelers FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_event_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_event_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_marathon_registrations audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_marathon_registrations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_messages audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_messages FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_overrides audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_overrides FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_transfer_expectations audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_transfer_expectations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_travel_preparations audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_travel_preparations FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: user_uniform_orders audit_trigger_row; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_row AFTER INSERT OR DELETE OR UPDATE ON year_2020.user_uniform_orders FOR EACH ROW EXECUTE FUNCTION auditing.if_modified_func('true', 'id', '{updated_at}');


--
-- Name: competing_teams audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.competing_teams FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: competing_teams_travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.competing_teams_travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_legs audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.flight_legs FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_schedules audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.flight_schedules FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: flight_tickets audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.flight_tickets FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: mailings audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.mailings FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meeting_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.meeting_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: meeting_video_views audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.meeting_video_views FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payment_items audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.payment_items FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payment_remittances audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.payment_remittances FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: payments audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.payments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: sent_mails audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.sent_mails FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: staff_assignment_visits audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.staff_assignment_visits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: staff_assignments audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.staff_assignments FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: student_lists audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.student_lists FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: teams audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.teams FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_buses audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_buses FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_buses_travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_buses_travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_credits audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_credits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_debits audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_debits FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_offers audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_offers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: traveler_rooms audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.traveler_rooms FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: travelers audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.travelers FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_event_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_event_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_marathon_registrations audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_marathon_registrations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_messages audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_messages FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_overrides audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_overrides FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_transfer_expectations audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_transfer_expectations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_travel_preparations audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_travel_preparations FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: user_uniform_orders audit_trigger_stm; Type: TRIGGER; Schema: year_2020; Owner: -
--

CREATE TRIGGER audit_trigger_stm AFTER TRUNCATE ON year_2020.user_uniform_orders FOR EACH STATEMENT EXECUTE FUNCTION auditing.if_modified_func('true');


--
-- Name: coaches fk_rails_019fa40eae; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT fk_rails_019fa40eae FOREIGN KEY (head_coach_id) REFERENCES public.coaches(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: privacy_policies fk_rails_0366c8ca8b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.privacy_policies
    ADD CONSTRAINT fk_rails_0366c8ca8b FOREIGN KEY (edited_by_id) REFERENCES public.users(id);


--
-- Name: invite_rules fk_rails_07eaf2e6ea; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_rules
    ADD CONSTRAINT fk_rails_07eaf2e6ea FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: user_ambassadors fk_rails_0c84f5af7f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ambassadors
    ADD CONSTRAINT fk_rails_0c84f5af7f FOREIGN KEY (ambassador_user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: users fk_rails_0ce9d27871; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_0ce9d27871 FOREIGN KEY (interest_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: event_results fk_rails_0d48300f79; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_results
    ADD CONSTRAINT fk_rails_0d48300f79 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE;


--
-- Name: officials fk_rails_1227a28f94; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.officials
    ADD CONSTRAINT fk_rails_1227a28f94 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE;


--
-- Name: user_refund_requests fk_rails_181b075f63; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_refund_requests
    ADD CONSTRAINT fk_rails_181b075f63 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: user_passports fk_rails_1822b1957d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passports
    ADD CONSTRAINT fk_rails_1822b1957d FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: user_interest_histories fk_rails_19304c5bb4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interest_histories
    ADD CONSTRAINT fk_rails_19304c5bb4 FOREIGN KEY (interest_id) REFERENCES public.interests(id);


--
-- Name: participants fk_rails_1c31d76900; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT fk_rails_1c31d76900 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: meetings fk_rails_1c7f0a9b0d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_1c7f0a9b0d FOREIGN KEY (host_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: participants fk_rails_23820ffbd6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participants
    ADD CONSTRAINT fk_rails_23820ffbd6 FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: import_athletes fk_rails_2d79db181b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_athletes
    ADD CONSTRAINT fk_rails_2d79db181b FOREIGN KEY (school_id) REFERENCES public.schools(id) DEFERRABLE;


--
-- Name: addresses fk_rails_2d87b6c11e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT fk_rails_2d87b6c11e FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: athletes_sports fk_rails_30d2f7a221; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes_sports
    ADD CONSTRAINT fk_rails_30d2f7a221 FOREIGN KEY (athlete_id) REFERENCES public.athletes(id) DEFERRABLE;


--
-- Name: payment_terms fk_rails_3388f6240c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.payment_terms
    ADD CONSTRAINT fk_rails_3388f6240c FOREIGN KEY (edited_by_id) REFERENCES public.users(id);


--
-- Name: coaches fk_rails_33a19e40b7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT fk_rails_33a19e40b7 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: athletes fk_rails_3438c8a31d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT fk_rails_3438c8a31d FOREIGN KEY (school_id) REFERENCES public.schools(id) DEFERRABLE;


--
-- Name: traveler_hotels fk_rails_34dc95bb44; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_hotels
    ADD CONSTRAINT fk_rails_34dc95bb44 FOREIGN KEY (address_id) REFERENCES public.addresses(id) DEFERRABLE;


--
-- Name: user_interest_histories fk_rails_38024aa7f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interest_histories
    ADD CONSTRAINT fk_rails_38024aa7f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: event_result_static_files fk_rails_39ef65e684; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.event_result_static_files
    ADD CONSTRAINT fk_rails_39ef65e684 FOREIGN KEY (event_result_id) REFERENCES public.event_results(id) DEFERRABLE;


--
-- Name: meetings fk_rails_3dc501a5b5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_3dc501a5b5 FOREIGN KEY (tech_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: flight_airports fk_rails_4c4c8ae552; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.flight_airports
    ADD CONSTRAINT fk_rails_4c4c8ae552 FOREIGN KEY (address_id) REFERENCES public.addresses(id);


--
-- Name: user_ambassadors fk_rails_58cbf1db3a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_ambassadors
    ADD CONSTRAINT fk_rails_58cbf1db3a FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: fundraising_idea_images fk_rails_6cc1cc062a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fundraising_idea_images
    ADD CONSTRAINT fk_rails_6cc1cc062a FOREIGN KEY (fundraising_idea_id) REFERENCES public.fundraising_ideas(id);


--
-- Name: shirt_order_shipments fk_rails_74abb24728; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_shipments
    ADD CONSTRAINT fk_rails_74abb24728 FOREIGN KEY (shirt_order_id) REFERENCES public.shirt_orders(id) DEFERRABLE;


--
-- Name: staff_clocks fk_rails_7a26fea858; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.staff_clocks
    ADD CONSTRAINT fk_rails_7a26fea858 FOREIGN KEY (staff_id) REFERENCES public.staffs(id);


--
-- Name: traveler_requests fk_rails_7b6e6f380e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.traveler_requests
    ADD CONSTRAINT fk_rails_7b6e6f380e FOREIGN KEY (traveler_id) REFERENCES public.travelers(id);


--
-- Name: address_variants fk_rails_800442053d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.address_variants
    ADD CONSTRAINT fk_rails_800442053d FOREIGN KEY (address_id) REFERENCES public.addresses(id) DEFERRABLE;


--
-- Name: user_interest_histories fk_rails_812086240c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_interest_histories
    ADD CONSTRAINT fk_rails_812086240c FOREIGN KEY (changed_by_id) REFERENCES public.users(id);


--
-- Name: athletes_sports fk_rails_889569fb78; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes_sports
    ADD CONSTRAINT fk_rails_889569fb78 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE;


--
-- Name: invite_rules fk_rails_89b7ef551c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.invite_rules
    ADD CONSTRAINT fk_rails_89b7ef551c FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: import_athletes fk_rails_8e8d068bd5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_athletes
    ADD CONSTRAINT fk_rails_8e8d068bd5 FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: user_relations fk_rails_8f78fb613a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relations
    ADD CONSTRAINT fk_rails_8f78fb613a FOREIGN KEY (related_user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: user_passports fk_rails_901b67c184; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passports
    ADD CONSTRAINT fk_rails_901b67c184 FOREIGN KEY (second_checker_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: officials fk_rails_95a091a415; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.officials
    ADD CONSTRAINT fk_rails_95a091a415 FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: user_passports fk_rails_9a89b97d88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_passports
    ADD CONSTRAINT fk_rails_9a89b97d88 FOREIGN KEY (checker_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: sport_events fk_rails_9dfac7872d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_events
    ADD CONSTRAINT fk_rails_9dfac7872d FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: athletes fk_rails_a2031fad05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT fk_rails_a2031fad05 FOREIGN KEY (source_id) REFERENCES public.sources(id) DEFERRABLE;


--
-- Name: import_matches fk_rails_a28b01aa32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_matches
    ADD CONSTRAINT fk_rails_a28b01aa32 FOREIGN KEY (school_id) REFERENCES public.schools(id) DEFERRABLE;


--
-- Name: thank_you_ticket_terms fk_rails_a37157355b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thank_you_ticket_terms
    ADD CONSTRAINT fk_rails_a37157355b FOREIGN KEY (edited_by_id) REFERENCES public.users(id);


--
-- Name: addresses fk_rails_a58360fa5b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.addresses
    ADD CONSTRAINT fk_rails_a58360fa5b FOREIGN KEY (student_list_id) REFERENCES public.student_lists(id) DEFERRABLE;


--
-- Name: sport_infos fk_rails_b024300b1c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sport_infos
    ADD CONSTRAINT fk_rails_b024300b1c FOREIGN KEY (sport_id) REFERENCES public.sports(id);


--
-- Name: coaches fk_rails_b63bfa1c6e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT fk_rails_b63bfa1c6e FOREIGN KEY (school_id) REFERENCES public.schools(id) DEFERRABLE;


--
-- Name: athletes fk_rails_b6b4420e7e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT fk_rails_b6b4420e7e FOREIGN KEY (competing_team_id) REFERENCES public.competing_teams(id) DEFERRABLE;


--
-- Name: athletes fk_rails_d3974226ab; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT fk_rails_d3974226ab FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: coaches fk_rails_d52e094e32; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coaches
    ADD CONSTRAINT fk_rails_d52e094e32 FOREIGN KEY (competing_team_id) REFERENCES public.competing_teams(id) DEFERRABLE;


--
-- Name: shirt_order_items fk_rails_d6e798a6bd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.shirt_order_items
    ADD CONSTRAINT fk_rails_d6e798a6bd FOREIGN KEY (shirt_order_id) REFERENCES public.shirt_orders(id) DEFERRABLE;


--
-- Name: users fk_rails_eb2fc738e4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_rails_eb2fc738e4 FOREIGN KEY (address_id) REFERENCES public.addresses(id) DEFERRABLE;


--
-- Name: import_athletes fk_rails_f2eb8014a8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_athletes
    ADD CONSTRAINT fk_rails_f2eb8014a8 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: import_matches fk_rails_f66807d7e0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_matches
    ADD CONSTRAINT fk_rails_f66807d7e0 FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE;


--
-- Name: chat_room_messages fk_rails_f7178a54ac; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_room_messages
    ADD CONSTRAINT fk_rails_f7178a54ac FOREIGN KEY (chat_room_id) REFERENCES public.chat_rooms(id);


--
-- Name: athletes fk_rails_f87477c7b8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.athletes
    ADD CONSTRAINT fk_rails_f87477c7b8 FOREIGN KEY (referring_coach_id) REFERENCES public.coaches(id) ON DELETE RESTRICT DEFERRABLE;


--
-- Name: schools fk_rails_f92e4f2669; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT fk_rails_f92e4f2669 FOREIGN KEY (address_id) REFERENCES public.addresses(id) DEFERRABLE;


--
-- Name: chat_room_messages fk_rails_ff6a8c6282; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_room_messages
    ADD CONSTRAINT fk_rails_ff6a8c6282 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: user_relationship_types user_relationship_type_inverse_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relationship_types
    ADD CONSTRAINT user_relationship_type_inverse_fk FOREIGN KEY (inverse) REFERENCES public.user_relationship_types(value) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_relationship_types user_relationship_type_value_fk; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_relationship_types
    ADD CONSTRAINT user_relationship_type_value_fk FOREIGN KEY (value) REFERENCES public.user_relationship_types(inverse) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_join_terms fk_rails_009ef169fb; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms
    ADD CONSTRAINT fk_rails_009ef169fb FOREIGN KEY (payment_id) REFERENCES year_2019.payments(id) DEFERRABLE;


--
-- Name: flight_schedules fk_rails_015cb0a1ee; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules
    ADD CONSTRAINT fk_rails_015cb0a1ee FOREIGN KEY (verified_by_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: mailings fk_rails_078492d090; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.mailings
    ADD CONSTRAINT fk_rails_078492d090 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_credits fk_rails_10c78e6467; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits
    ADD CONSTRAINT fk_rails_10c78e6467 FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_uniform_orders fk_rails_122e144357; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders
    ADD CONSTRAINT fk_rails_122e144357 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams fk_rails_135dcb4f53; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams
    ADD CONSTRAINT fk_rails_135dcb4f53 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses fk_rails_1448083c52; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses
    ADD CONSTRAINT fk_rails_1448083c52 FOREIGN KEY (hotel_id) REFERENCES public.traveler_hotels(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses_travelers fk_rails_190e8614fe; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses_travelers
    ADD CONSTRAINT fk_rails_190e8614fe FOREIGN KEY (bus_id) REFERENCES year_2019.traveler_buses(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_1b8b15c0d3; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits
    ADD CONSTRAINT fk_rails_1b8b15c0d3 FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses_travelers fk_rails_1feffa24ac; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses_travelers
    ADD CONSTRAINT fk_rails_1feffa24ac FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_tickets fk_rails_26e5419f6e; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets
    ADD CONSTRAINT fk_rails_26e5419f6e FOREIGN KEY (schedule_id) REFERENCES year_2019.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_uniform_orders fk_rails_2b02690df6; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders
    ADD CONSTRAINT fk_rails_2b02690df6 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: travelers fk_rails_3184ca6546; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers
    ADD CONSTRAINT fk_rails_3184ca6546 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_uniform_orders fk_rails_32fb06a39b; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_uniform_orders
    ADD CONSTRAINT fk_rails_32fb06a39b FOREIGN KEY (submitter_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_items fk_rails_35775c70bf; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items
    ADD CONSTRAINT fk_rails_35775c70bf FOREIGN KEY (payment_id) REFERENCES year_2019.payments(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_travel_preparations fk_rails_35da0d92f0; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_travel_preparations
    ADD CONSTRAINT fk_rails_35da0d92f0 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: traveler_requests fk_rails_364e176a88; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_requests
    ADD CONSTRAINT fk_rails_364e176a88 FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) DEFERRABLE;


--
-- Name: flight_legs fk_rails_40f96912b5; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs
    ADD CONSTRAINT fk_rails_40f96912b5 FOREIGN KEY (departing_airport_id) REFERENCES public.flight_airports(id) ON DELETE RESTRICT;


--
-- Name: flight_schedules fk_rails_423e60c26e; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_schedules
    ADD CONSTRAINT fk_rails_423e60c26e FOREIGN KEY (parent_schedule_id) REFERENCES year_2019.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_messages fk_rails_4339dda614; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages
    ADD CONSTRAINT fk_rails_4339dda614 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_registrations fk_rails_43d1dca006; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations
    ADD CONSTRAINT fk_rails_43d1dca006 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_registrations fk_rails_461c1c3f8a; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations
    ADD CONSTRAINT fk_rails_461c1c3f8a FOREIGN KEY (athlete_id) REFERENCES public.athletes(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payments fk_rails_5381dabbe0; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments
    ADD CONSTRAINT fk_rails_5381dabbe0 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_rooms fk_rails_54925c252d; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms
    ADD CONSTRAINT fk_rails_54925c252d FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_messages fk_rails_564510584f; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_messages
    ADD CONSTRAINT fk_rails_564510584f FOREIGN KEY (staff_id) REFERENCES public.staffs(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: teams fk_rails_585082cc88; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams
    ADD CONSTRAINT fk_rails_585082cc88 FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_rooms fk_rails_649c289027; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_rooms
    ADD CONSTRAINT fk_rails_649c289027 FOREIGN KEY (hotel_id) REFERENCES public.traveler_hotels(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignment_visits fk_rails_6ccb849d4c; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignment_visits
    ADD CONSTRAINT fk_rails_6ccb849d4c FOREIGN KEY (assignment_id) REFERENCES year_2019.staff_assignments(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_event_registrations fk_rails_6d0821cc54; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations
    ADD CONSTRAINT fk_rails_6d0821cc54 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_event_registrations fk_rails_701d84c24f; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_event_registrations
    ADD CONSTRAINT fk_rails_701d84c24f FOREIGN KEY (submitter_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: teams fk_rails_796c1522a7; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams
    ADD CONSTRAINT fk_rails_796c1522a7 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_legs fk_rails_7d5fceff55; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs
    ADD CONSTRAINT fk_rails_7d5fceff55 FOREIGN KEY (arriving_airport_id) REFERENCES public.flight_airports(id) ON DELETE RESTRICT;


--
-- Name: user_overrides fk_rails_7f99ed7f62; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_overrides
    ADD CONSTRAINT fk_rails_7f99ed7f62 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_tickets fk_rails_803fcbc313; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_tickets
    ADD CONSTRAINT fk_rails_803fcbc313 FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: travelers fk_rails_81f2e0c8b7; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.travelers
    ADD CONSTRAINT fk_rails_81f2e0c8b7 FOREIGN KEY (team_id) REFERENCES year_2019.teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_82c38b2dbe; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments
    ADD CONSTRAINT fk_rails_82c38b2dbe FOREIGN KEY (assigned_by_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_838e46be30; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views
    ADD CONSTRAINT fk_rails_838e46be30 FOREIGN KEY (video_id) REFERENCES public.meeting_videos(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_897ab773a0; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views
    ADD CONSTRAINT fk_rails_897ab773a0 FOREIGN KEY (athlete_id) REFERENCES public.athletes(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_credits fk_rails_8a8afac83f; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_credits
    ADD CONSTRAINT fk_rails_8a8afac83f FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_transfer_expectations fk_rails_98dfba379e; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_transfer_expectations
    ADD CONSTRAINT fk_rails_98dfba379e FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: payment_items fk_rails_9e4f008d32; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_items
    ADD CONSTRAINT fk_rails_9e4f008d32 FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_legs fk_rails_9ed5258554; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.flight_legs
    ADD CONSTRAINT fk_rails_9ed5258554 FOREIGN KEY (schedule_id) REFERENCES year_2019.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses fk_rails_a8d2381dd3; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_buses
    ADD CONSTRAINT fk_rails_a8d2381dd3 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_ad0235e073; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments
    ADD CONSTRAINT fk_rails_ad0235e073 FOREIGN KEY (assigned_to_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: teams fk_rails_ad7904d48a; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.teams
    ADD CONSTRAINT fk_rails_ad7904d48a FOREIGN KEY (competing_team_id) REFERENCES year_2019.competing_teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_marathon_registrations fk_rails_b3aecc3c4d; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.user_marathon_registrations
    ADD CONSTRAINT fk_rails_b3aecc3c4d FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_bb0b965b79; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.staff_assignments
    ADD CONSTRAINT fk_rails_bb0b965b79 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_offers fk_rails_bd894ad688; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers
    ADD CONSTRAINT fk_rails_bd894ad688 FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_bd9d05cc7e; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits
    ADD CONSTRAINT fk_rails_bd9d05cc7e FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_ca3ac8bfa0; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_debits
    ADD CONSTRAINT fk_rails_ca3ac8bfa0 FOREIGN KEY (base_debit_id) REFERENCES public.traveler_base_debits(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_registrations fk_rails_ccf9794e68; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_registrations
    ADD CONSTRAINT fk_rails_ccf9794e68 FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_cf87d3bac8; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.meeting_video_views
    ADD CONSTRAINT fk_rails_cf87d3bac8 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams_travelers fk_rails_e351944a05; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams_travelers
    ADD CONSTRAINT fk_rails_e351944a05 FOREIGN KEY (traveler_id) REFERENCES year_2019.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams_travelers fk_rails_ed997d2955; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.competing_teams_travelers
    ADD CONSTRAINT fk_rails_ed997d2955 FOREIGN KEY (competing_team_id) REFERENCES year_2019.competing_teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payments fk_rails_f45938c572; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payments
    ADD CONSTRAINT fk_rails_f45938c572 FOREIGN KEY (shirt_order_id) REFERENCES public.shirt_orders(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_join_terms fk_rails_f5000acb70; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.payment_join_terms
    ADD CONSTRAINT fk_rails_f5000acb70 FOREIGN KEY (terms_id) REFERENCES public.payment_terms(id) DEFERRABLE;


--
-- Name: traveler_offers fk_rails_fa1e181bc8; Type: FK CONSTRAINT; Schema: year_2019; Owner: -
--

ALTER TABLE ONLY year_2019.traveler_offers
    ADD CONSTRAINT fk_rails_fa1e181bc8 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_overrides fk_rails_10d536e9b5; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_overrides
    ADD CONSTRAINT fk_rails_10d536e9b5 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_offers fk_rails_10d823fb90; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers
    ADD CONSTRAINT fk_rails_10d823fb90 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_offers fk_rails_1efe29f4a3; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_offers
    ADD CONSTRAINT fk_rails_1efe29f4a3 FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_requests fk_rails_21286a2095; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_requests
    ADD CONSTRAINT fk_rails_21286a2095 FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) DEFERRABLE;


--
-- Name: user_uniform_orders fk_rails_241b7e4bc6; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders
    ADD CONSTRAINT fk_rails_241b7e4bc6 FOREIGN KEY (submitter_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_event_registrations fk_rails_28a60b49a0; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations
    ADD CONSTRAINT fk_rails_28a60b49a0 FOREIGN KEY (submitter_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_2be64bd861; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments
    ADD CONSTRAINT fk_rails_2be64bd861 FOREIGN KEY (assigned_by_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_messages fk_rails_2cd4eafce8; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages
    ADD CONSTRAINT fk_rails_2cd4eafce8 FOREIGN KEY (staff_id) REFERENCES public.staffs(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: mailings fk_rails_2d22c6a9b1; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.mailings
    ADD CONSTRAINT fk_rails_2d22c6a9b1 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_join_terms fk_rails_33963d8ace; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms
    ADD CONSTRAINT fk_rails_33963d8ace FOREIGN KEY (payment_id) REFERENCES year_2020.payments(id) DEFERRABLE;


--
-- Name: payments fk_rails_34dae7e1c6; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments
    ADD CONSTRAINT fk_rails_34dae7e1c6 FOREIGN KEY (shirt_order_id) REFERENCES public.shirt_orders(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_35d1c258b3; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits
    ADD CONSTRAINT fk_rails_35d1c258b3 FOREIGN KEY (base_debit_id) REFERENCES public.traveler_base_debits(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_transfer_expectations fk_rails_39bff55f46; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_transfer_expectations
    ADD CONSTRAINT fk_rails_39bff55f46 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: teams fk_rails_3b43e5b666; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams
    ADD CONSTRAINT fk_rails_3b43e5b666 FOREIGN KEY (competing_team_id) REFERENCES year_2020.competing_teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_3db1d478d6; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits
    ADD CONSTRAINT fk_rails_3db1d478d6 FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_uniform_orders fk_rails_3dfda279df; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders
    ADD CONSTRAINT fk_rails_3dfda279df FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_registrations fk_rails_3f0d0603af; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations
    ADD CONSTRAINT fk_rails_3f0d0603af FOREIGN KEY (meeting_id) REFERENCES public.meetings(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payments fk_rails_4aca15544a; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payments
    ADD CONSTRAINT fk_rails_4aca15544a FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams fk_rails_4cd6d4a588; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams
    ADD CONSTRAINT fk_rails_4cd6d4a588 FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses fk_rails_4f626dad1e; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses
    ADD CONSTRAINT fk_rails_4f626dad1e FOREIGN KEY (hotel_id) REFERENCES public.traveler_hotels(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_schedules fk_rails_51f0353571; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules
    ADD CONSTRAINT fk_rails_51f0353571 FOREIGN KEY (parent_schedule_id) REFERENCES year_2020.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams_travelers fk_rails_568dc476e4; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams_travelers
    ADD CONSTRAINT fk_rails_568dc476e4 FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_credits fk_rails_64f73329e5; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits
    ADD CONSTRAINT fk_rails_64f73329e5 FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_registrations fk_rails_67b9ad2295; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations
    ADD CONSTRAINT fk_rails_67b9ad2295 FOREIGN KEY (athlete_id) REFERENCES public.athletes(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_rooms fk_rails_718269ed93; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms
    ADD CONSTRAINT fk_rails_718269ed93 FOREIGN KEY (hotel_id) REFERENCES public.traveler_hotels(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_tickets fk_rails_75d4276952; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets
    ADD CONSTRAINT fk_rails_75d4276952 FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_join_terms fk_rails_76474e08df; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_join_terms
    ADD CONSTRAINT fk_rails_76474e08df FOREIGN KEY (terms_id) REFERENCES public.payment_terms(id) DEFERRABLE;


--
-- Name: staff_assignment_visits fk_rails_768ae872cb; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignment_visits
    ADD CONSTRAINT fk_rails_768ae872cb FOREIGN KEY (assignment_id) REFERENCES year_2020.staff_assignments(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: competing_teams_travelers fk_rails_80c3468427; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.competing_teams_travelers
    ADD CONSTRAINT fk_rails_80c3468427 FOREIGN KEY (competing_team_id) REFERENCES year_2020.competing_teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses_travelers fk_rails_853999cded; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses_travelers
    ADD CONSTRAINT fk_rails_853999cded FOREIGN KEY (bus_id) REFERENCES year_2020.traveler_buses(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_legs fk_rails_859d592629; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs
    ADD CONSTRAINT fk_rails_859d592629 FOREIGN KEY (arriving_airport_id) REFERENCES public.flight_airports(id) ON DELETE RESTRICT;


--
-- Name: flight_schedules fk_rails_873ea7e37a; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_schedules
    ADD CONSTRAINT fk_rails_873ea7e37a FOREIGN KEY (verified_by_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_88a47b69cb; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments
    ADD CONSTRAINT fk_rails_88a47b69cb FOREIGN KEY (assigned_to_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_uniform_orders fk_rails_8c3caa4394; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_uniform_orders
    ADD CONSTRAINT fk_rails_8c3caa4394 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_credits fk_rails_8f2f2c050a; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_credits
    ADD CONSTRAINT fk_rails_8f2f2c050a FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: teams fk_rails_9a6cc6100e; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams
    ADD CONSTRAINT fk_rails_9a6cc6100e FOREIGN KEY (sport_id) REFERENCES public.sports(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses fk_rails_9aedcbec23; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses
    ADD CONSTRAINT fk_rails_9aedcbec23 FOREIGN KEY (sport_id) REFERENCES public.sports(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_b7193958b8; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views
    ADD CONSTRAINT fk_rails_b7193958b8 FOREIGN KEY (video_id) REFERENCES public.meeting_videos(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_c11af02983; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views
    ADD CONSTRAINT fk_rails_c11af02983 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: staff_assignments fk_rails_c51868b6cc; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.staff_assignments
    ADD CONSTRAINT fk_rails_c51868b6cc FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_debits fk_rails_c57078d3ed; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_debits
    ADD CONSTRAINT fk_rails_c57078d3ed FOREIGN KEY (assigner_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_legs fk_rails_c930e801c9; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs
    ADD CONSTRAINT fk_rails_c930e801c9 FOREIGN KEY (departing_airport_id) REFERENCES public.flight_airports(id) ON DELETE RESTRICT;


--
-- Name: teams fk_rails_cb7b90ad4e; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.teams
    ADD CONSTRAINT fk_rails_cb7b90ad4e FOREIGN KEY (state_id) REFERENCES public.states(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_rooms fk_rails_cd7b14c30e; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_rooms
    ADD CONSTRAINT fk_rails_cd7b14c30e FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: travelers fk_rails_ce123f5294; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers
    ADD CONSTRAINT fk_rails_ce123f5294 FOREIGN KEY (team_id) REFERENCES year_2020.teams(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_event_registrations fk_rails_d071f49697; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_event_registrations
    ADD CONSTRAINT fk_rails_d071f49697 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: travelers fk_rails_d1a3059ab8; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.travelers
    ADD CONSTRAINT fk_rails_d1a3059ab8 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: meeting_video_views fk_rails_d3143a56f9; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_video_views
    ADD CONSTRAINT fk_rails_d3143a56f9 FOREIGN KEY (athlete_id) REFERENCES public.athletes(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_travel_preparations fk_rails_d328a68478; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_travel_preparations
    ADD CONSTRAINT fk_rails_d328a68478 FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE;


--
-- Name: meeting_registrations fk_rails_d996d20cad; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.meeting_registrations
    ADD CONSTRAINT fk_rails_d996d20cad FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_items fk_rails_dbf997f768; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items
    ADD CONSTRAINT fk_rails_dbf997f768 FOREIGN KEY (payment_id) REFERENCES year_2020.payments(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_legs fk_rails_ddaa729fc9; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_legs
    ADD CONSTRAINT fk_rails_ddaa729fc9 FOREIGN KEY (schedule_id) REFERENCES year_2020.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: flight_tickets fk_rails_df6f9830ca; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.flight_tickets
    ADD CONSTRAINT fk_rails_df6f9830ca FOREIGN KEY (schedule_id) REFERENCES year_2020.flight_schedules(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_marathon_registrations fk_rails_f5710e519c; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_marathon_registrations
    ADD CONSTRAINT fk_rails_f5710e519c FOREIGN KEY (user_id) REFERENCES public.users(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: traveler_buses_travelers fk_rails_f617ee6232; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.traveler_buses_travelers
    ADD CONSTRAINT fk_rails_f617ee6232 FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: payment_items fk_rails_fcb6e5649d; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.payment_items
    ADD CONSTRAINT fk_rails_fcb6e5649d FOREIGN KEY (traveler_id) REFERENCES year_2020.travelers(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- Name: user_messages fk_rails_ffe8c89d72; Type: FK CONSTRAINT; Schema: year_2020; Owner: -
--

ALTER TABLE ONLY year_2020.user_messages
    ADD CONSTRAINT fk_rails_ffe8c89d72 FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT DEFERRABLE INITIALLY DEFERRED;


--
-- PostgreSQL database dump complete
--

SET search_path TO public,public;

INSERT INTO "schema_migrations" (version) VALUES
('20180518042050'),
('20180518042060'),
('20180518042070'),
('20180518042100'),
('20180710180500'),
('20180710180510'),
('20180710180520'),
('20180710180523'),
('20180710180610'),
('20180710180620'),
('20180710180800'),
('20180710180810'),
('20180710180820'),
('20180718225346'),
('20180719030701'),
('20180719162010'),
('20180719162020'),
('20180719162030'),
('20180719162040'),
('20180719162050'),
('20180719162427'),
('20180723233618'),
('20180723233632'),
('20180723233717'),
('20180723234502'),
('20180831160932'),
('20180831171501'),
('20180905233809'),
('20180906003325'),
('20180906024125'),
('20180907163653'),
('20180914215704'),
('20180914215835'),
('20180914215951'),
('20180914220904'),
('20180914220926'),
('20180914221357'),
('20180914233507'),
('20180914233733'),
('20180914233828'),
('20180915100000'),
('20180917200215'),
('20180917203617'),
('20180927185158'),
('20181029204843'),
('20181101205421'),
('20181101205823'),
('20181212012730'),
('20181212024210'),
('20181220205311'),
('20181228230236'),
('20190109003246'),
('20190109012949'),
('20190109233619'),
('20190123230154'),
('20190123230155'),
('20190130175309'),
('20190204185657'),
('20190209050942'),
('20190209052337'),
('20190209212555'),
('20190209230921'),
('20190215224000'),
('20190218215927'),
('20190220171127'),
('20190221012229'),
('20190227202628'),
('20190308002234'),
('20190321211943'),
('20190322172124'),
('20190322172125'),
('20190404172129'),
('20190404172130'),
('20190404172131'),
('20190405033752'),
('20190411173528'),
('20190411174006'),
('20190416230925'),
('20190416231030'),
('20190420172903'),
('20190502181010'),
('20190506163044'),
('20190506163350'),
('20190506164246'),
('20190506164341'),
('20190507201812'),
('20190521231821'),
('20190525223405'),
('20190525223659'),
('20190525225506'),
('20190603184131'),
('20190604213801'),
('20190621185539'),
('20190703183824'),
('20190703184439'),
('20190824022359'),
('20190824022432'),
('20190824022435'),
('20190824022439'),
('20190827202101'),
('20190904173747'),
('20190904195333'),
('20190905185513'),
('20190906000403'),
('20190906154856'),
('20190909225134'),
('20190918194446'),
('20190925230837'),
('20190926193210'),
('20191004141110'),
('20191011164531'),
('20191231174201'),
('20191231174252'),
('20200108194424'),
('20200127205447'),
('20200129003804'),
('20200204111111'),
('20200205222655'),
('20200206014832'),
('20200217203844'),
('20200306205929'),
('20200323172526'),
('20200326011539'),
('20200327164625'),
('20200407141011'),
('20200511221632'),
('20200511222029'),
('20200531122420');


