# This migration comes from better_record (originally 20190416215152)
class AddThreeStateBooleanType < ActiveRecord::Migration[5.2]
  def up
  end
  def up
    execute <<-SQL
      DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'three_state') THEN
            CREATE TYPE three_state AS ENUM ('Y', 'N', 'U');
          END IF;
        END
      $$;
    SQL
  end

  def down
    execute "DROP TYPE IF EXISTS three_state;"
  end
end
