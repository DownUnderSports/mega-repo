# This migration comes from better_record (originally 20190123225641)
class AddExchangeRateIntegerType < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'exchange_rate_integer') THEN
            CREATE DOMAIN exchange_rate_integer AS BIGINT NOT NULL DEFAULT 0;
          END IF;
        END
      $$;
    SQL
  end

  def down
    execute "DROP DOMAIN IF EXISTS exchange_rate_integer;"
  end
end
