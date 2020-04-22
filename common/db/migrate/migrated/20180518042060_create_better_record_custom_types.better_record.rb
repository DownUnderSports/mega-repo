# This migration comes from better_record (originally 20180518042060)
class CreateBetterRecordCustomTypes < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'gender') THEN
            CREATE TYPE gender AS ENUM ('F', 'M', 'U');
          END IF;
        END
      $$;
    SQL

    execute <<-SQL
      DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'money_integer') THEN
            CREATE DOMAIN money_integer AS INTEGER NOT NULL DEFAULT 0;
          END IF;
        END
      $$;
    SQL

  end

  def down
    execute "DROP DOMAIN IF EXISTS money_integer;"
    execute "DROP TYPE IF EXISTS gender;"
  end
end
