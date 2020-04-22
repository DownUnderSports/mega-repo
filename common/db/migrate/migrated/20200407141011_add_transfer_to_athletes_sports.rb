class AddTransferToAthletesSports < ActiveRecord::Migration[5.2]
  def up
    execute "DROP TRIGGER IF EXISTS audit_trigger_row ON athletes_sports;"
    execute "DROP TRIGGER IF EXISTS audit_trigger_stm ON athletes_sports;"

    reversible do |d|
      d.up do
        execute <<-SQL
          CREATE TYPE transferability
            AS ENUM (
              'always',
              'necessary',
              'none'
            );
        SQL
      end

      d.down do
        execute <<-SQL
          DROP TYPE transferability;
        SQL
      end
    end

    change_table "public.athletes_sports" do |t|
      t.column :transferability, :transferability

      t.index [ :transferability ], name: 'athletes_sports_transferable_idx'
    end

    audit_table "athletes_sports"
  end
end
