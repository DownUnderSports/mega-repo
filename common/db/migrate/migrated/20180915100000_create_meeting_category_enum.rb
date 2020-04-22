class CreateMeetingCategoryEnum < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DO $$
        BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'meeting_category') THEN
            CREATE TYPE meeting_category AS ENUM ('I', 'D', 'S', 'A', 'P', 'F');
          END IF;
        END
      $$;
    SQL
  end
end
