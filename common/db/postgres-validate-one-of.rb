class AddValidateOneOfFunction < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION validate_one_of() RETURNS TRIGGER AS
      $BODY$
      DECLARE
          col text;
          columns text[];
          has_value boolean;
          _placeholder_bool boolean;
      BEGIN
        has_value = 'FALSE'::boolean;
        columns = TG_ARGV[0]::text[];

        FOREACH col IN ARRAY columns
        LOOP
          EXECUTE format('SELECT CASE WHEN ($1).%1$I IS NULL THEN ''FALSE''::boolean ELSE ''TRUE''::boolean END AS status', col)
          USING NEW
          INTO _placeholder_bool;


          IF _placeholder_bool IS TRUE THEN
            RAISE EXCEPTION 'value was %', _placeholder_bool::text;
            has_value = 'TRUE'::boolean;
          END IF;

          EXIT WHEN has_value IS TRUE;
        END LOOP;

        IF has_value IS FALSE THEN
          RAISE EXCEPTION 'Not all required fields submitted'
          USING HINT = 'One of "' || array_to_string(columns, ' | ') || '" must be filled out';
        END IF;
        RETURN NULL;
      END;
      $BODY$
      LANGUAGE plpgsql;
    SQL
  end
  def down
    execute <<-SQL
      DROP FUNCTION IF EXISTS validate_one_of();
    SQL
  end
end
