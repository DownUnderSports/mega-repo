class CreateUnsubscriberCategoryEnum < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DO $$
        BEGIN
          DROP TYPE IF EXISTS unsubscriber_category;
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'unsubscriber_category') THEN
            CREATE TYPE unsubscriber_category AS ENUM ('C', 'E', 'M', 'T');
          END IF;
        END
      $$;
    SQL
  end
end
