require 'db/views'

Views.destroy_all(self)

#==== GET INDEXES ===
<<-SQL
  SELECT i.relname as indname,
         i.relowner as indowner,
         idx.indrelid::regclass
  FROM   pg_index as idx
  JOIN   pg_class as i
  ON     i.oid = idx.indexrelid
  JOIN   pg_am as am
  ON     i.relam = am.oid
  JOIN   pg_namespace as ns
  ON     ns.oid = i.relnamespace
  AND    ns.nspname = ANY(current_schemas(false))
  WHERE idx.indrelid::regclass::text = 'users';
SQL

#===== MIGRATION ===

execute "DROP TRIGGER audit_trigger_row ON users;"

execute "DROP TRIGGER audit_trigger_stm ON users;"

execute "DROP TRIGGER user_insert ON users;"

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

rename_table :users, :old_users

create_table :users do |t|
  t.text :dus_id, null: false, default: -> { "unique_random_string('users', 'dus_id', 6)" }
  t.references :category, polymorphic: true
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

  t.index [ :dus_id ], unique: true

  t.timestamps default: -> { 'NOW()' }
end

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

execute <<-SQL
  INSERT INTO users
  (
    id,
    dus_id,
    category_type,
    category_id,
    email,
    password,
    register_secret,
    certificate,
    title,
    first,
    middle,
    last,
    suffix,
    print_first_names,
    print_other_names,
    nick_name,
    keep_name,
    address_id,
    interest_id,
    extension,
    phone,
    can_text,
    gender,
    shirt_size,
    birth_date,
    transfer_id,
    created_at,
    updated_at
  )
  SELECT
    id,
    dus_id,
    category_type,
    category_id,
    email,
    password,
    register_secret,
    certificate,
    title,
    first,
    middle,
    last,
    suffix,
    print_first_names,
    print_other_names,
    nick_name,
    keep_name,
    address_id,
    interest_id,
    extension,
    phone,
    can_text,
    gender,
    shirt_size,
    birth_date,
    transfer_id,
    created_at,
    updated_at
  FROM old_users
SQL

ActiveRecord::Base.connection.reset_pk_sequence!('users')

ActiveRecord::Base.connection.execute(
  <<-SQL
    SELECT DISTINCT
      tc.table_schema,
      tc.constraint_name,
      tc.table_name,
      kcu.column_name,
      ccu.table_schema AS foreign_table_schema,
      ccu.table_name AS foreign_table_name,
      ccu.column_name AS foreign_column_name
    FROM
      information_schema.table_constraints AS tc
      JOIN information_schema.key_column_usage AS kcu
        ON tc.constraint_name = kcu.constraint_name
        AND tc.table_schema = kcu.table_schema
      JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name
        AND ccu.table_schema = tc.table_schema
    WHERE constraint_type = 'FOREIGN KEY' AND ccu.table_name = 'old_users';

  SQL
).each do |row|
  r = row.to_h.deep_symbolize_keys
  constraint_name = r[:constraint_name]
  execute <<-SQL
    ALTER TABLE "#{r[:table_schema]}"."#{r[:table_name]}"
      DROP CONSTRAINT "#{r[:constraint_name]}";
  SQL

  execute <<-SQL
    ALTER TABLE "#{r[:table_schema]}"."#{r[:table_name]}"
      ADD CONSTRAINT "#{r[:constraint_name]}"
      FOREIGN KEY (#{r[:column_name]})
      REFERENCES "#{r[:foreign_table_schema]}"."users" (#{r[:foreign_column_name]})
      ON DELETE RESTRICT
  SQL
end

audit_table :users, true, false, %w(password register_secret certificate)
login_triggers :users, ['password', 'certificate']

drop_table :old_users
