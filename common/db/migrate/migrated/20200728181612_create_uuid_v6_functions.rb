class CreateUuidV6Functions < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
      CREATE OR REPLACE FUNCTION uuid_v1_to_v6(v1 uuid)
      RETURNS uuid AS $$
      DECLARE
          v6 text;
      BEGIN
          SELECT substring(v1::text from 16 for 3) ||
                  substring(v1::text from 10 for 4) ||
                  substring(v1::text from 1 for 5)  ||
                  '6' || substring(v1::text from 6 for 3) ||
                  substring(v1::text from 20)

                  INTO v6;

          RETURN v6::uuid;

      END; $$
      LANGUAGE PLPGSQL;

      CREATE OR REPLACE FUNCTION uuid_generate_v6mc()
      RETURNS uuid AS $$
      BEGIN
          RETURN uuid_v1_to_v6(uuid_generate_v1mc());
      END; $$
      LANGUAGE PLPGSQL;

      CREATE OR REPLACE FUNCTION uuid_generate_v6()
      RETURNS uuid AS $$
      BEGIN
          RETURN uuid_v1_to_v6(uuid_generate_v1());
      END; $$
      LANGUAGE PLPGSQL;
    SQL

    change_column_default :chat_rooms, :id, -> { 'uuid_generate_v6()'}
  end
end
