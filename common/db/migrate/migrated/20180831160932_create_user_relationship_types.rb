class CreateUserRelationshipTypes < ActiveRecord::Migration[5.2]
  def change
    create_table :user_relationship_types, id: false do |t|
      t.text :value, null: false
      t.text :inverse, null: false

      t.index [:value, :inverse]
      t.index [:inverse, :value]
    end

    reversible do |d|
      d.up do
        execute <<-SQL
          ALTER TABLE user_relationship_types
            ADD CONSTRAINT user_relationship_type_value_pk PRIMARY KEY (value);
          ALTER TABLE user_relationship_types
            ADD CONSTRAINT user_relationship_type_inverse_uniqueness UNIQUE (inverse);
          ALTER TABLE user_relationship_types
            ADD CONSTRAINT user_relationship_type_value_fk FOREIGN KEY (value)
                REFERENCES user_relationship_types (inverse)
                           DEFERRABLE INITIALLY DEFERRED;
          ALTER TABLE user_relationship_types
            ADD CONSTRAINT user_relationship_type_inverse_fk FOREIGN KEY (inverse)
                REFERENCES user_relationship_types (value)
                           DEFERRABLE INITIALLY DEFERRED;
        SQL

        execute <<-SQL
          CREATE OR REPLACE FUNCTION create_inverse_relationship_type(text, text)
          RETURNS void AS
          $BODY$
            BEGIN
              IF NOT EXISTS ( SELECT * FROM user_relationship_types WHERE ( inverse = $1 )) THEN
                INSERT INTO user_relationship_types (value, inverse)
                VALUES ( $2, $1 );
              END IF;
            END;
          $BODY$
          LANGUAGE plpgsql;
        SQL

        execute <<-SQL
          CREATE OR REPLACE FUNCTION relationship_type_insert()
            RETURNS trigger AS
          $BODY$
          BEGIN
            PERFORM create_inverse_relationship_type(NEW.value, NEW.inverse);

            RETURN NEW;
          END;
          $BODY$
          LANGUAGE plpgsql;
        SQL

        execute <<-SQL
          CREATE OR REPLACE FUNCTION relationship_type_update()
            RETURNS trigger AS
          $BODY$
          BEGIN
            IF EXISTS ( SELECT * FROM user_relationship_types WHERE ( inverse =  OLD.value) ) THEN
              DELETE FROM user_relationship_types WHERE ( inverse = $3 );
            END IF;

            PERFORM create_inverse_relationship_type(NEW.value, NEW.inverse);

            RETURN NEW;
          END;
          $BODY$
          LANGUAGE plpgsql;
        SQL

        execute <<-SQL
          CREATE TRIGGER relationship_type_insert
          AFTER INSERT ON user_relationship_types
          FOR EACH ROW
          EXECUTE PROCEDURE relationship_type_insert();
        SQL

        execute <<-SQL
          CREATE TRIGGER relationship_type_update
          AFTER UPDATE ON user_relationship_types
          FOR EACH ROW
          EXECUTE PROCEDURE relationship_type_update();
        SQL
      end

      d.down do
        execute "DROP TRIGGER IF EXISTS relationship_type_update ON user_relationship_types"
        execute "DROP TRIGGER IF EXISTS relationship_type_insert ON user_relationship_types"
        execute "DROP FUNCTION IF EXISTS relationship_type_update"
        execute "DROP FUNCTION IF EXISTS relationship_type_insert"
        execute "DROP FUNCTION IF EXISTS create_inverse_relationship_type"
        execute <<-SQL
          ALTER TABLE user_relationship_types
          DROP CONSTRAINT user_relationship_type_inverse_fk,
          DROP CONSTRAINT user_relationship_type_value_fk,
          DROP CONSTRAINT user_relationship_type_inverse_uniqueness,
          DROP CONSTRAINT user_relationship_type_value_pk;
        SQL
      end
    end
  end
end
