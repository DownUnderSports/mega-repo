class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.text :dus_id, null: false, default: -> { "unique_random_string('users', 'dus_id', 6)" }
      t.references :category, polymorphic: true, index: false
      t.text :email
      t.text :password
      t.text :register_secret
      t.text :certificate
      t.text :title
      t.text :first, null: false
      t.text :middle
      t.text :last, null: false
      t.text :suffix
      t.text :print_first_names
      t.text :print_other_names
      t.text :nick_name
      t.boolean :keep_name, null: false, default: false
      t.references :address, foreign_key: true
      t.references :interest, null: false, foreign_key: true, default: -> { "5" }
      t.text :extension
      t.text :phone
      t.boolean :can_text, null: false, default: true
      t.gender :gender, null: false, index: true, default: 'U'
      t.text :shirt_size
      t.date :birth_date
      t.integer :transfer_id
      t.datetime :responded_at
      t.boolean :is_verified, null: false, default: false
      t.integer :visible_until_year

      t.index [ :dus_id ], unique: true
      t.index [ :category_type, :category_id ], unique: true
      t.index [ :responded_at ]
      t.index [ :visible_until_year ]

      t.timestamps default: -> { 'NOW()' }
    end

    audit_table :users, true, false, %w[ password register_secret certificate updated_at ]
    login_triggers :users, ['password', 'certificate']

    reversible do |d|
      d.up do
        execute <<-SQL
          ALTER TABLE users
            ADD CONSTRAINT user_email_must_exist_if_password_exists CHECK (
              (password IS NULL) OR (email IS NOT NULL)
            );
        SQL

        execute <<-SQL
          ALTER TABLE users
            ADD CONSTRAINT user_has_valid_category CHECK (
              ((category_type IS NULL) AND (category_id IS NULL)) OR (
                category_type IN ('Athlete', 'Coach', 'Official', 'Staff', 'athletes', 'coaches', 'officials', 'staffs')
              )
            );
        SQL

        execute <<-SQL
          ALTER TABLE users
            ADD CONSTRAINT user_has_valid_shirt_size CHECK (
              (shirt_size IS NULL) OR (
                shirt_size IN (
                  'Y-XS', 'Y-S', 'Y-M', 'Y-L',
                  'A-S', 'A-M', 'A-L',
                  'A-XL', 'A-2XL', 'A-3XL', 'A-4XL'
                )
              )
            );
        SQL

        execute "CREATE INDEX users_first_name_search_idx ON users USING gin (first gin_trgm_ops);"

        execute "CREATE INDEX users_last_name_search_idx ON users USING gin (last gin_trgm_ops);"

        execute "CREATE INDEX users_print_first_names_search_idx ON users USING gin (print_first_names gin_trgm_ops);"

        execute "CREATE INDEX users_print_other_names_search_idx ON users USING gin (print_other_names gin_trgm_ops);"

        execute "CREATE INDEX users_dus_id_hash_idx ON users USING hash (digest(dus_id, 'sha256'));"

        execute <<-SQL
          CREATE TRIGGER user_insert
          BEFORE INSERT OR UPDATE ON users
          FOR EACH ROW
          EXECUTE PROCEDURE valid_email_trigger();
        SQL
      end

      d.down do
        execute "DROP INDEX IF EXISTS users_dus_id_hash_idx;"

        execute "DROP INDEX IF EXISTS users_print_other_names_search_idx;"

        execute "DROP INDEX IF EXISTS users_print_first_names_search_idx;"

        execute "DROP INDEX IF EXISTS users_last_name_search_idx;"

        execute "DROP INDEX IF EXISTS users_first_name_search_idx;"

        execute <<-SQL
          ALTER TABLE users
            DROP CONSTRAINT IF EXISTS user_email_must_exist_if_password_exists;
        SQL

        execute <<-SQL
          ALTER TABLE users
            DROP CONSTRAINT IF EXISTS user_has_valid_category;
        SQL

        execute <<-SQL
          ALTER TABLE users
            DROP CONSTRAINT IF EXISTS user_has_valid_shirt_size;
        SQL

        execute "DROP TRIGGER user_insert ON users;"
      end
    end
  end
end
