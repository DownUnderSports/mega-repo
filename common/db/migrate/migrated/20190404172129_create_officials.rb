class CreateOfficials < ActiveRecord::Migration[5.2]
  def change
    create_table :officials do |t|
      t.references :team, null: false, foreign_key: true
      t.text :category, default: -> { "'official'::text" }

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :officials

    reversible do |d|
      d.up do
        execute <<-SQL
          ALTER TABLE users
            DROP CONSTRAINT IF EXISTS user_has_valid_category;
        SQL

        execute <<-SQL
          ALTER TABLE users
            ADD CONSTRAINT user_has_valid_category CHECK (
              ((category_type IS NULL) AND (category_id IS NULL)) OR (
                category_type IN ('Athlete', 'Coach', 'Official', 'Staff', 'athletes', 'coaches', 'officials', 'staffs')
              )
            );
        SQL
      end

      d.down do
        execute <<-SQL
          DELETE FROM users
            WHERE category_type IN ('Official', 'officials');
        SQL

        execute <<-SQL
          ALTER TABLE users
            DROP CONSTRAINT IF EXISTS user_has_valid_category;
        SQL

        execute <<-SQL
          ALTER TABLE users
            ADD CONSTRAINT user_has_valid_category CHECK (
              ((category_type IS NULL) AND (category_id IS NULL)) OR (
                category_type IN ('Athlete', 'Coach', 'Official', 'Staff', 'athletes', 'coaches', 'officials', 'staffs')
              )
            );
        SQL
      end
    end
  end
end
